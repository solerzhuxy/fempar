! Copyright (C) 2014 Santiago Badia, Alberto F. Martín and Javier Principe
!
! This file is part of FEMPAR (Finite Element Multiphysics PARallel library)
!
! FEMPAR is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! FEMPAR is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with FEMPAR. If not, see <http://www.gnu.org/licenses/>.
!
! Additional permission under GNU GPL version 3 section 7
!
! If you modify this Program, or any covered work, by linking or combining it 
! with the Intel Math Kernel Library and/or the Watson Sparse Matrix Package 
! and/or the HSL Mathematical Software Library (or a modified version of them), 
! containing parts covered by the terms of their respective licenses, the
! licensors of this Program grant you additional permission to convey the 
! resulting work. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# include "debug.i90"
module fem_triangulation_names
  use types_names
  use memor_names
  use fem_space_types_names
  use hash_table_names
  implicit none
  private

  integer(ip), parameter :: triangulation_not_created  = 0 ! Initial state
  integer(ip), parameter :: triangulation_filled       = 1 ! Elems + Objects arrays allocated and filled 

  type elem_topology_t
     integer(ip)               :: num_objects = -1    ! Number of objects
     integer(ip), allocatable  :: objects(:)          ! List of Local IDs of the objects (vertices, edges, faces) that make up this element
     type(fem_fixed_info_t), pointer :: topology => NULL() ! Topological info of the geometry (SBmod)
     
     real(rp), allocatable     :: coordinates(:,:)
     integer(ip)               :: order

  end type elem_topology_t

  type object_topology_t
     integer(ip)               :: border     = -1       ! Border local id of this object (only for faces)
     integer(ip)               :: dimension             ! Object dimension (SBmod)
     integer(ip)               :: num_elems_around = -1 ! Number of elements around object 
     integer(ip), allocatable  :: elems_around(:)       ! List of elements around object 
  end type object_topology_t

  type fem_triangulation_t
     integer(ip) :: state          =  triangulation_not_created  
     integer(ip) :: num_objects    = -1  ! number of objects 
     integer(ip) :: num_elems      = -1  ! number of elements
     integer(ip) :: num_dims       = -1  ! number of dimensions
     integer(ip) :: elem_array_len = -1  ! length that the elements array is allocated for. 
     type(elem_topology_t), allocatable    :: elems(:) ! array of elements in the mesh.
     type(object_topology_t) , allocatable :: objects(:) ! array of objects in the mesh.
     type (position_hash_table_t)          :: pos_elem_info  ! Topological info hash table (SBmod)
     type (fem_fixed_info_t)               :: lelem_info(max_elinf) ! List of topological info's
     integer(ip)                         :: num_boundary_faces ! Number of faces in the boundary 
     integer(ip), allocatable            :: lst_boundary_faces(:) ! List of faces LIDs in the boundary
  end type fem_triangulation_t

  ! Types
  public :: fem_triangulation_t

  ! Main Subroutines 
  public :: fem_triangulation_create, fem_triangulation_free, fem_triangulation_to_dual, triangulation_print

  ! Auxiliary Subroutines (should only be used by modules that have control over type(fem_triangulation_t))
  public :: free_elem_topology, free_object_topology, put_topology_element_triangulation, local_id_from_vertices

  ! Constants (should only be used by modules that have control over type(fem_triangulation_t))
  public :: triangulation_not_created, triangulation_filled
  public :: fem_triangulation_free_elems_data, fem_triangulation_free_objs_data

contains

  !=============================================================================
  subroutine fem_triangulation_create(len,trian)
    implicit none
    integer(ip)            , intent(in)    :: len
    type(fem_triangulation_t), intent(inout) :: trian
    integer(ip) :: istat,ielem

    trian%elem_array_len = len
    trian%num_objects = -1
    trian%num_elems = -1
    trian%num_dims = -1 

    ! Allocate the element structure array 
    allocate(trian%elems(trian%elem_array_len), stat=istat)
    check(istat==0)

    ! Initialize all of the element structs
    do ielem = 1, trian%elem_array_len
       call initialize_elem_topology(trian%elems(ielem))
    end do

    ! Initialization of element fixed info parameters (SBmod)
    call trian%pos_elem_info%init(ht_length)


  end subroutine fem_triangulation_create

  !=============================================================================
  subroutine fem_triangulation_free(trian)
    implicit none
    type(fem_triangulation_t), intent(inout) :: trian
    integer(ip) :: istat,ielem, iobj

    assert(trian%state == triangulation_filled) 

    call fem_triangulation_free_elems_data(trian)
    call fem_triangulation_free_objs_data(trian)
    call memfree ( trian%lst_boundary_faces, __FILE__, __LINE__ )

    ! Deallocate the element structure array */
    deallocate(trian%elems, stat=istat)
    check(istat==0)

    ! Deallocate fixed info
    do iobj = 1,trian%pos_elem_info%last()
       call fem_element_fixed_info_free (trian%lelem_info(iobj))
    end do
    call trian%pos_elem_info%free

    trian%elem_array_len = -1 
    trian%num_objects = -1
    trian%num_elems = -1
    trian%num_dims = -1 

    trian%state = triangulation_not_created
  end subroutine fem_triangulation_free

  subroutine fem_triangulation_free_objs_data(trian)
    implicit none
    type(fem_triangulation_t), intent(inout) :: trian
    integer(ip) :: istat,ielem, iobj
    
    if ( trian%state == triangulation_filled ) then
       do iobj=1, trian%num_objects 
          call free_object_topology(trian%objects(iobj)) 
       end do
       ! Deallocate the object structure array 
       deallocate(trian%objects, stat=istat)
       check(istat==0)
    end if
  end subroutine fem_triangulation_free_objs_data

  subroutine fem_triangulation_free_elems_data(trian)
    implicit none
    type(fem_triangulation_t), intent(inout) :: trian
    integer(ip) :: istat,ielem, iobj
    
    if ( trian%state == triangulation_filled ) then
       do ielem=1, trian%elem_array_len 
          call free_elem_topology(trian%elems(ielem)) 
       end do
    end if

  end subroutine fem_triangulation_free_elems_data

  ! Auxiliary subroutines
  subroutine initialize_object_topology (object)
    implicit none
    type(object_topology_t), intent(inout) :: object

    assert(.not.allocated(object%elems_around))
    object%num_elems_around = 0 
  end subroutine initialize_object_topology

  subroutine free_object_topology (object)
    implicit none
    type(object_topology_t), intent(inout) :: object

    if (allocated(object%elems_around)) then
       call memfree(object%elems_around, __FILE__, __LINE__)
    end if
    object%num_elems_around = -1
  end subroutine free_object_topology

  subroutine free_elem_topology(element)
    implicit none
    type(elem_topology_t), intent(inout) :: element

    if (allocated(element%objects)) then
       call memfree(element%objects, __FILE__, __LINE__)
    end if

    if (allocated(element%coordinates)) then
       call memfree(element%coordinates, __FILE__, __LINE__)
    end if

    element%num_objects = -1
    nullify( element%topology )
  end subroutine free_elem_topology

  subroutine initialize_elem_topology(element)
    implicit none
    type(elem_topology_t), intent(inout) :: element

    assert(.not. allocated(element%objects))
    element%num_objects = -1
  end subroutine initialize_elem_topology

  subroutine fem_triangulation_to_dual(trian, length_trian)  
    implicit none
    ! Parameters
    type(fem_triangulation_t), intent(inout) :: trian
    integer(ip), optional, intent(in)      :: length_trian

    ! Locals
    integer(ip)              :: ielem, iobj, jobj, istat, idime, touch,  length_trian_
    type(hash_table_ip_ip_t)   :: visited
    integer(ip), allocatable :: elems_around_pos(:)
    
    if (present(length_trian)) then
       length_trian_ = length_trian
    else
       length_trian_ = trian%num_elems 
    endif

    ! Count objects
    call visited%init(max(5,int(real(length_trian_,rp)*0.2_rp,ip))) 
    trian%num_objects = 0
    touch = 1
    do ielem=1, length_trian_
       do iobj=1, trian%elems(ielem)%num_objects
          jobj = trian%elems(ielem)%objects(iobj)
          if (jobj /= -1) then ! jobj == -1 if object belongs to neighbouring processor
             !call visited%put(key=jobj, val=1, stat=istat)
             call visited%put(key=jobj, val=touch, stat=istat)
             if (istat == now_stored) trian%num_objects = trian%num_objects + 1
          end if
       end do
    end do
    call visited%free

    ! Allocate the object structure array 
    allocate(trian%objects(trian%num_objects), stat=istat)
    check(istat==0)
    do iobj=1, trian%num_objects
       call initialize_object_topology(trian%objects(iobj))
    end do

    ! Count elements around each object
    do ielem=1, length_trian_
       do iobj=1, trian%elems(ielem)%num_objects
          jobj = trian%elems(ielem)%objects(iobj)
          if (jobj /= -1) then ! jobj == -1 if object belongs to neighbouring processor
             trian%objects(jobj)%num_elems_around = trian%objects(jobj)%num_elems_around + 1 
          end if
       end do
    end do

    call memalloc ( trian%num_objects, elems_around_pos, __FILE__, __LINE__ )
    elems_around_pos = 1

    !call triangulation_print( 6, trian, length_trian_ )

    ! List elements and add object dimension
    do ielem=1, length_trian_
       do idime =1, trian%num_dims    ! (SBmod)
          do iobj = trian%elems(ielem)%topology%nobje_dim(idime), &
               trian%elems(ielem)%topology%nobje_dim(idime+1)-1 
             !do iobj=1, trian%elems(ielem)%num_objects
             jobj = trian%elems(ielem)%objects(iobj)
             if (jobj /= -1) then ! jobj == -1 if object belongs to neighbouring processor
                trian%objects(jobj)%dimension = idime-1
                if (elems_around_pos(jobj) == 1) then
                   call memalloc( trian%objects(jobj)%num_elems_around, trian%objects(jobj)%elems_around, __FILE__, __LINE__ )
                end if
                trian%objects(jobj)%elems_around(elems_around_pos(jobj)) = ielem
                elems_around_pos(jobj) = elems_around_pos(jobj) + 1 
             end if
          end do
       end do
    end do

    ! Assign border and count boundary faces
    trian%num_boundary_faces = 0
    do iobj = 1, trian%num_objects
       if ( trian%objects(iobj)%dimension == trian%num_dims -1 ) then
          if ( trian%objects(iobj)%num_elems_around == 1 ) then 
             trian%num_boundary_faces = trian%num_boundary_faces + 1
             trian%objects(iobj)%border = trian%num_boundary_faces
          end if
       end if
    end do

    ! List boundary faces
    call memalloc (  trian%num_boundary_faces, trian%lst_boundary_faces,  __FILE__, __LINE__ )
    do iobj = 1, trian%num_objects
       if ( trian%objects(iobj)%dimension == trian%num_dims -1 ) then
          if ( trian%objects(iobj)%num_elems_around == 1 ) then 
             trian%lst_boundary_faces(trian%objects(iobj)%border) = iobj
          end if
       end if
    end do

    call memfree ( elems_around_pos, __FILE__, __LINE__ )

    trian%state = triangulation_filled


  end subroutine fem_triangulation_to_dual

  subroutine put_topology_element_triangulation( ielem, trian ) !(SBmod)
    implicit none
    type(fem_triangulation_t), intent(inout), target :: trian
    integer(ip),             intent(in)            :: ielem
    ! Locals
    integer(ip) :: nobje, v_key, ndime, etype, pos_elinf, istat
    logical(lg) :: created
    integer(ip) :: aux_val

    nobje = trian%elems(ielem)%num_objects 
    ndime = trian%num_dims

    ! Variable values depending of the element ndime
    etype = 0
    if(ndime == 2) then        ! 2D
       if(nobje == 6) then     ! Linear triangles (P1)
          etype = P_type_id
       elseif(nobje == 8) then ! Linear quads (Q1)
          etype = Q_type_id
       end if
    elseif(ndime == 3) then    ! 3D
       if(nobje == 14) then     ! Linear tetrahedra (P1)
          etype = P_type_id
       elseif(nobje == 26) then ! Linear hexahedra (Q1)
          etype = Q_type_id
       end if
    end if
    assert( etype /= 0 )

    ! Assign pointer to topological information
    v_key = ndime + (max_ndime+1)*etype + (max_ndime+1)*(max_FE_types+1)
    call trian%pos_elem_info%get(key=v_key,val=pos_elinf,stat=istat)
    if ( istat == new_index) then
       ! Create fixed info if not constructed
       call fem_element_fixed_info_create(trian%lelem_info(pos_elinf),etype,  &
            &                                     1,ndime,created)
    end if
    trian%elems(ielem)%topology => trian%lelem_info(pos_elinf)

  end subroutine put_topology_element_triangulation

  subroutine local_id_from_vertices( e, nd, list, no, lid ) ! (SBmod)
    implicit none
    type(elem_topology_t), intent(in) :: e
    integer(ip), intent(in)  :: nd, list(:), no
    integer(ip), intent(out) :: lid
    ! Locals
    integer(ip)              :: first, last, io, iv, jv, ivl, c
    lid = -1

    do io = e%topology%nobje_dim(nd), e%topology%nobje_dim(nd+1)-1
       first =  e%topology%crxob%p(io)
       last = e%topology%crxob%p(io+1) -1
       if ( last - first + 1  == no ) then 
          do iv = first,last
             ivl = e%objects(e%topology%crxob%l(iv)) ! LID of vertices of the ef
             c = 0
             do jv = 1,no
                if ( ivl ==  list(jv) ) then
                   c  = 1 ! vertex in the external ef
                   exit
                end if
             end do
             if (c == 0) exit
          end do
          if (c == 1) then ! object in the external element
             lid = e%objects(io)
             exit
          end if
       end if
    end do
  end subroutine local_id_from_vertices

  subroutine triangulation_print ( lunou,  trian, length_trian ) ! (SBmod)
    implicit none
    ! Parameters
    integer(ip)            , intent(in) :: lunou
    type(fem_triangulation_t), intent(in) :: trian
    integer(ip), optional, intent(in)      :: length_trian

    ! Locals
    integer(ip) :: ielem, iobje, length_trian_

    if (present(length_trian)) then
       length_trian_ = length_trian
    else
       length_trian_ = trian%num_elems 
    endif


    write (lunou,*) '****PRINT TOPOLOGY****'
    write (lunou,*) 'state:', trian%state
    write (lunou,*) 'num_objects:', trian%num_objects
    write (lunou,*) 'num_elems:', trian%num_elems
    write (lunou,*) 'num_dims:', trian%num_dims
    write (lunou,*) 'elem_array_len:', trian%elem_array_len


    do ielem = 1, length_trian_
       write (lunou,*) '****PRINT ELEMENT ',ielem,' INFO****'

       write (lunou,*) 'num_objects:', trian%elems(ielem)%num_objects
       write (lunou,*) 'objects:', trian%elems(ielem)%objects
       write (lunou,*) 'coordinates:', trian%elems(ielem)%coordinates
       write (lunou,*) 'order:', trian%elems(ielem)%order

       !call fem_element_fixed_info_write ( trian%elems(ielem)%topology )

       write (lunou,*) '****END PRINT ELEMENT ',ielem,' INFO****'
    end do

    do iobje = 1, trian%num_objects
       write (lunou,*) '****PRINT OBJECT ',iobje,' INFO****'

       write (lunou,*) 'border', trian%objects(iobje)%border
       write (lunou,*) 'dimension', trian%objects(iobje)%dimension
       write (lunou,*) 'num_elems_around', trian%objects(iobje)%num_elems_around
       write (lunou,*) 'elems_around', trian%objects(iobje)%elems_around

       write (lunou,*) '****END PRINT OBJECT ',iobje,' INFO****'
    end do

    
    write (lunou,*) '****END PRINT TOPOLOGY****'
  end subroutine triangulation_print

end module fem_triangulation_names
