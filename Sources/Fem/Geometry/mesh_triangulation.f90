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
module mesh_triangulation
  use types
  use memor
  use fem_mesh_names
  use fem_triangulation_names
  use fem_space_types
  use geom2topo

  implicit none
# include "debug.i90"
  private

  public :: mesh_to_triangulation

contains

  subroutine mesh_to_triangulation (gmesh,trian)
    implicit none
    ! Parameters
    type(fem_mesh), intent(inout)          :: gmesh ! Geometry mesh
    type(fem_triangulation), intent(inout) :: trian 

    ! Locals
    type(fem_mesh) :: tmesh ! Topological mesh
    integer(ip)    :: istat, ielem, iobj
    integer(ip)    :: count, g_node, inode, p

    assert(trian%state == triangulation_created .or. trian%state == triangulation_elems_filled .or. trian%state == triangulation_elems_objects_filled)

    trian%num_elems = gmesh%nelem
    trian%num_dims  = gmesh%ndime

    call fem_triangulation_free_elems_data(trian)
    call fem_triangulation_free_objs_data(trian)

!!$     AFM: I think this is not really needed. trian%elems could already be
!!$     allocated with sufficient size (see next if-end block)
!!$     if ( trian%state == triangulation_elems_objects_filled .or. &
!!$          trian%state == triangulation_elems_filled ) then
!!$       ! Deallocate the element structure array */
!!$       deallocate(trian%elems, stat=istat)
!!$       check(istat==0)
!!$       trian%elem_array_len = -1
!!$    end if

    if ( trian%num_elems > trian%elem_array_len ) then
       if (allocated(trian%elems)) then
          deallocate(trian%elems, stat=istat)
          check(istat==0)
       end if
       allocate(trian%elems(trian%num_elems), stat=istat)
       check(istat==0)
       trian%elem_array_len = trian%num_elems
    end if

    call geom2topo_mesh_cond(gmesh, tmesh)

    do ielem=1, trian%num_elems
       trian%elems(ielem)%num_objects = tmesh%pnods(ielem+1)-tmesh%pnods(ielem)
       call memalloc(trian%elems(ielem)%num_objects, trian%elems(ielem)%objects, __FILE__, __LINE__)
       trian%elems(ielem)%objects(1:trian%elems(ielem)%num_objects) = tmesh%lnods(tmesh%pnods(ielem):tmesh%pnods(ielem+1)-1)
    end do

    do ielem=1, trian%num_elems !(SBmod)
       call put_topology_element_triangulation ( ielem, trian )
    end do

    call fem_mesh_free(tmesh)
    trian%state = triangulation_elems_filled


    if( allocated(gmesh%coord) ) then
       do ielem = 1, trian%num_elems
          call memalloc( gmesh%pnods(ielem+1)-gmesh%pnods(ielem), trian%num_dims, &
               & trian%elems(ielem)%coordinates, __FILE__, __LINE__ )
          count = 0
          do inode = gmesh%pnods(ielem),gmesh%pnods(ielem+1)-1
             count = count+1
             g_node = gmesh%lnods(inode)
             trian%elems(ielem)%coordinates(count,1:trian%num_dims) = gmesh%coord(g_node,1:trian%num_dims)
          end do
          trian%elems(ielem)%order = get_order( trian%elems(ielem)%topology%ftype, count, trian%num_dims )
       end do
    end if

  end subroutine mesh_to_triangulation

end module mesh_triangulation



















