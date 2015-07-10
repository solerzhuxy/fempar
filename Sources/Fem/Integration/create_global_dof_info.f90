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
module create_global_dof_info_names
  use types_names
  use array_names
  use memor_names
  use triangulation_names
  use fe_space_names
  use dof_descriptor_names
  use fe_space_types_names
  use hash_table_names
  use graph_names
  use block_graph_names
  use sort_names
  implicit none
# include "debug.i90"
  private

  public :: create_dof_info, create_element_to_dof_and_ndofs, create_vef2dof, &
       & create_dof_graph_block


contains

  !*********************************************************************************
  ! This subroutine generates ALL the DOF-related work for serial runs.
  ! 1) It generates DOF numbering and fills the elem2dof arrays (see explanation of 
  !    the subroutine below)
  ! 2) It generates the vef2dof array ( see explanation of the subroutine below)
  ! 3) It generates the local graph (to be extended in *par_create_global_dof_info_names*
  !    to put additional DOFs due to face integration coupling with DOFs from ghost 
  !    elements) ( see explanation of the subroutine below and *ghost_dofs_by_integration*
  !    in *par_create_global_dof_info_names* for more insight)

  ! NOTE: In order to understand the following subroutines, it is useful to know that 
  ! currently, the *par_fe_space* (parallel) has a pointer to a *fe_space*, which 
  ! has not info about the distributed environment (since it is a serial object),
  ! but it includes the *num_elems* local elements + *num_ghosts* ghost elements.
  ! The ghost part is filled in *par_fe_space_create*. Thus, we know if we have a
  ! local or ghost element below checking whether *ielem* <=  *num_elems* (local)
  ! or not. We are using this trick below in some cases, to be able to use the same
  ! subroutines for parallel runs, and fill properly ghost info. For serial runs, 
  ! the only thing is that *ielem* <=  *num_elems* always, so it never goes to the
  ! ghost element part.
  !*********************************************************************************
  subroutine create_dof_info ( dof_descriptor, trian, fe_space, f_blk_graph, gtype ) ! graph
    implicit none
    ! Dummy arguments
    type(dof_descriptor_t)              , intent(in)    :: dof_descriptor
    type(triangulation_t)        , intent(in)    :: trian 
    type(fe_space_t)                , intent(inout) :: fe_space 
    type(block_graph_t)          , intent(inout) :: f_blk_graph 
    integer(ip)          , optional, intent(in)    :: gtype(dof_descriptor%nblocks) 

    ! Locals
    integer(ip) :: iblock, jblock
    type(graph_t), pointer :: f_graph


    call create_element_to_dof_and_ndofs( dof_descriptor, trian, fe_space )

    call create_vef2dof( dof_descriptor, trian, fe_space )

    ! Create block graph
    call f_blk_graph%alloc(dof_descriptor%nblocks)

    ! To be called after the reordering of dofs
    do iblock = 1, dof_descriptor%nblocks
       do jblock = 1, dof_descriptor%nblocks
          f_graph => f_blk_graph%get_block(iblock,jblock)
          if ( iblock == jblock .and. present(gtype) ) then
             call create_dof_graph_block ( iblock, jblock, dof_descriptor, trian, fe_space, f_graph, gtype(iblock) )
          else
             call create_dof_graph_block ( iblock, jblock, dof_descriptor, trian, fe_space, f_graph )
          end if
       end do
    end do

  end subroutine create_dof_info

  !*********************************************************************************
  ! This subroutine takes the triangulation, the dof handler, and the triangulation 
  ! and fills the element2dof structure at every finite element, i.e., it labels all
  ! dofs related to local elements (not ghost), after a count-list procedure, and
  ! puts the number of dofs in ndofs structure (per block).
  ! Note 1: The numbering is per every block independently, where the blocks are 
  ! defined at the dof_descriptor. A global dof numbering is not needed in the code, 
  ! when blocks are being used.
  !*********************************************************************************
  subroutine create_element_to_dof_and_ndofs( dof_descriptor, trian, fe_space ) 
    implicit none
    ! Parameters
    type(dof_descriptor_t), intent(in)             :: dof_descriptor
    type(triangulation_t), intent(in)       :: trian 
    type(fe_space_t), intent(inout)            :: fe_space 

    ! Local variables
    integer(ip) :: iprob, l_var, iblock, count, iobje, ielem, jelem, nvapb, ivars, g_var
    integer(ip) :: obje_l, inode, l_node, elem_ext, obje_ext, prob_ext, l_var_ext, inode_ext, inode_l
    integer(ip) :: mater, order, nnode
    integer(ip) :: touch(fe_space%num_continuity,dof_descriptor%nvars_global,2)

    integer(ip)     :: o2n(max_nnode)

    call memalloc ( dof_descriptor%nblocks, fe_space%ndofs, __FILE__, __LINE__ )

    do iblock = 1, dof_descriptor%nblocks  
       count = 0

       ! Part 1: Put DOFs on VEFs, taking into account that DOFs only belong to VEFs when we do not
       ! enforce continuity (continuity(ielem) /= 0). We go through all objects, elements around the
       ! object, variables of the element, and if for the value of continuity of this element no 
       ! DOFs have already been added, we add them and touch this object for this continuity value.
       ! In FEMPAR, continuity is an elemental value. If it is different from 0, the nodes/DOFs 
       ! geometrically on the interface belong to the interface objects (VEFs). Next, we only
       ! enforce continuity for elements with same continuity value (mater below), in order to 
       ! allow for situations in which we want to have continuity in patches and discontinuity among 
       ! patches based on physical arguments (every patch would involve its own value of continuity).
       ! For hp-adaptivity, we could consider the value in continuity to be p (order) and as a result
       ! not to enforce continuity among elements with different order SINCE it would lead to ERROR
       ! to enforce continuity among elements of different order.
       do iobje = 1, trian%num_vefs          
          touch = 0
          do ielem = 1, trian%vefs(iobje)%num_elems_around
             jelem = trian%vefs(iobje)%elems_around(ielem)
             iprob = fe_space%finite_elements(jelem)%problem
             nvapb = dof_descriptor%prob_block(iblock,iprob)%nd1
             if ( jelem <= trian%num_elems ) then ! Local elements
                do ivars = 1, nvapb
                   l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
                   g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
                   if ( fe_space%finite_elements(jelem)%continuity(g_var) /= 0 ) then
                      mater = fe_space%finite_elements(jelem)%continuity(g_var) ! SB.alert : continuity can be used as p 
                      do obje_l = 1, trian%elems(jelem)%num_vefs
                         if ( trian%elems(jelem)%vefs(obje_l) == iobje ) exit
                      end do
                      if ( fe_space%finite_elements(jelem)%bc_code(l_var,obje_l) == 0 ) then
                         if ( touch(mater,g_var,1) == 0 ) then                            
                            touch(mater,g_var,1) = jelem
                            touch(mater,g_var,2) = obje_l
                            call put_new_vefs_dofs_in_vef_of_element ( dof_descriptor, trian, fe_space, g_var, jelem, l_var, &
                                 count, obje_l )
                         else
                            call put_existing_vefs_dofs_in_vef_of_element ( dof_descriptor, trian, fe_space, touch, mater, g_var, iobje, &
                                 &                                          jelem, l_var, o2n, obje_l )
                         end if
                      end if
                   end if
                end do
             else ! Ghost elements
                do ivars = 1, nvapb
                   l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
                   g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
                   if ( fe_space%finite_elements(jelem)%continuity(g_var) /= 0 ) then
                      mater = fe_space%finite_elements(jelem)%continuity(g_var) ! SB.alert : continuity can be used as p 
                      do obje_l = 1, trian%elems(jelem)%num_vefs
                         if ( trian%elems(jelem)%vefs(obje_l) == iobje ) exit
                      end do
                      if ( touch(mater,g_var,1) /= 0) then
                         call put_existing_vefs_dofs_in_vef_of_element ( dof_descriptor, trian, fe_space, touch, mater, g_var, iobje, &
                              &                                          jelem, l_var, o2n, obje_l )
                      end if
                   end if
                end do
             end if
          end do
       end do

       ! Part 2: Put DOFs on nodes belonging to the volume object (element). For cG we only do that when 
       ! static condensation is not active. Static condensation is for all variables, elements, etc. BUT
       ! it cannot be used with dG. The following algorithm is ASSUMING that this is the case, and we are
       ! not using dG + static condensations. In any case, when creating the fe_space there is an 
       ! automatic check for satisfying that.
       ! No check about strong Dirichlet boundary conditions, because they are imposed weakly in dG, and
       ! never appear in interior nodes in cG.
       if ( ( .not. fe_space%static_condensation )  ) then
          do ielem = 1, trian%num_elems
             iprob = fe_space%finite_elements(ielem)%problem
             nvapb = dof_descriptor%prob_block(iblock,iprob)%nd1
             do ivars = 1, nvapb
                l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
                g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var) 
                iobje = trian%elems(ielem)%num_vefs+1
                do inode = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje), &
                     &     fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje+1)-1 
                   l_node = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%l(inode)
                   count = count +1
                   fe_space%finite_elements(ielem)%elem2dof(l_node,l_var) = count
                end do
             end do
          end do
       end if

       ! Part 3: Assign total number of dofs created to fem space object
       fe_space%ndofs(iblock) = count
    end do

  end subroutine create_element_to_dof_and_ndofs

  !*********************************************************************************
  ! This subroutine takes the triangulation, the dof handler, and the triangulation 
  ! and fills the vef2dof structure. The vef2dof structure puts on top of VEFs
  ! the DOFs that are meant to be continuous between elements with the same continuity
  ! label. As an example, when using dG only, vef2dof is void. It is more an 
  ! acceleration array than a really needed structure, but it is convenient when
  ! creating the dof graph. 
  !*********************************************************************************
  subroutine create_vef2dof ( dof_descriptor, trian, fe_space ) 
    implicit none
    ! Parameters
    type(dof_descriptor_t), intent(in)             :: dof_descriptor
    type(triangulation_t), intent(in)       :: trian 
    type(fe_space_t), intent(inout)            :: fe_space 

    ! Local variables
    integer(ip) :: iprob, l_var, iblock, count, iobje, ielem, jelem, nvapb, ivars, g_var
    integer(ip) :: obje_l, inode, l_node, mater, istat
    integer(ip) :: touch(dof_descriptor%nvars_global,fe_space%num_continuity)

    allocate( fe_space%vef2dof(dof_descriptor%nblocks), stat = istat )
    check( istat == 0)

    ! Part 1: Count DOFs on VEFs, using the notion of continuity described above (in elem2dof)
    do iblock = 1, dof_descriptor%nblocks  
       fe_space%vef2dof(iblock)%n1 = trian%num_vefs
       fe_space%vef2dof(iblock)%n2 = 3
       call memalloc ( trian%num_vefs+1, fe_space%vef2dof(iblock)%p, __FILE__, __LINE__, 0 )
       do iobje = 1, trian%num_vefs
          touch = 0
          do ielem = 1, trian%vefs(iobje)%num_elems_around
             jelem = trian%vefs(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then 
                iprob = fe_space%finite_elements(jelem)%problem
                nvapb = dof_descriptor%prob_block(iblock,iprob)%nd1
                do ivars = 1, nvapb
                   l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
                   g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
                   mater = fe_space%finite_elements(jelem)%continuity(g_var) 
                   if ( mater /= 0 ) then
                      if ( touch(g_var,mater) == 0 ) then
                         touch(g_var,mater) = 1
                         do obje_l = 1, trian%elems(jelem)%num_vefs
                            if ( trian%elems(jelem)%vefs(obje_l) == iobje ) exit
                         end do
                         if ( fe_space%finite_elements(jelem)%bc_code(l_var,obje_l) == 0 ) then
                            fe_space%vef2dof(iblock)%p(iobje+1) = fe_space%vef2dof(iblock)%p(iobje+1) + fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l+1) &
                                 & - fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l)
                         end if
                      end if
                   end if
                end do
             end if
          end do
       end do

       fe_space%vef2dof(iblock)%p(1) = 1
       do iobje = 2, trian%num_vefs+1
          fe_space%vef2dof(iblock)%p(iobje) = fe_space%vef2dof(iblock)%p(iobje) + fe_space%vef2dof(iblock)%p(iobje-1)
       end do

       call memalloc ( fe_space%vef2dof(iblock)%p(trian%num_vefs+1)-1, 3, fe_space%vef2dof(iblock)%l, __FILE__, __LINE__ )

       ! Part 2: List DOFs on VEFs, using the notion of continuity described above (in elem2dof)
       ! We note that the vef2dof(iblock)%l(:,X) is defined for X = 1,2,3
       ! vef2dof(iblock)%l(:,1) : DOF LID
       ! vef2dof(iblock)%l(:,2) : Variable GID associated to that DOF
       ! vef2dof(iblock)%l(:,3) : Continuity value associated to that DOF (to enforce continuity)
       count = 0
       do iobje = 1, trian%num_vefs
          touch = 0
          do ielem = 1, trian%vefs(iobje)%num_elems_around
             jelem = trian%vefs(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then 
                iprob = fe_space%finite_elements(jelem)%problem
                nvapb = dof_descriptor%prob_block(iblock,iprob)%nd1
                do ivars = 1, nvapb
                   l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
                   g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
                   mater = fe_space%finite_elements(jelem)%continuity(g_var)
                   if ( mater /= 0) then
                      if ( touch(g_var,mater) == 0 ) then
                         touch(g_var,mater) = 1
                         do obje_l = 1, trian%elems(jelem)%num_vefs
                            if ( trian%elems(jelem)%vefs(obje_l) == iobje ) exit
                         end do
                         if ( fe_space%finite_elements(jelem)%bc_code(l_var,obje_l) == 0 ) then
                            do inode = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l), &
                                 &     fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l+1)-1 
                               l_node = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%l(inode)
                               count = count + 1
                               fe_space%vef2dof(iblock)%l(count,1) = fe_space%finite_elements(jelem)%elem2dof(l_node,l_var)
                               fe_space%vef2dof(iblock)%l(count,2) = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
                               fe_space%vef2dof(iblock)%l(count,3) = mater
                            end do
                         end if
                      end if
                   end if
                end do
             end if
          end do
       end do
    end do
  end subroutine create_vef2dof

  !*********************************************************************************
  ! This subroutine takes the triangulation, the dof handler, and the triangulation 
  ! and creates a dof_graph. The dof_graph includes both the coupling by continuity
  ! like in continuous Galerkin methods, and the coupling by face terms (of 
  ! discontinuous Galerkin type). The algorithm considers both the case with static 
  ! condensation and without it. In order to call this subroutine, we need to compute 
  ! first element2dof and vef2dof arrays.
  !*********************************************************************************
  subroutine create_dof_graph_block( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, gtype ) 
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(out)                :: dof_graph
    integer(ip), optional, intent(in)           :: gtype


    ! Local variables
    integer(ip) :: iprob, l_var, count, iobje, ielem, jelem, nvapb, ivars, g_var, inter, inode, l_node
    integer(ip) :: ltype, idof, jdof, int_i, int_j, istat, jnode, job_g, jobje, jvars, k_var , touch
    integer(ip) :: l_dof, m_dof, m_node, m_var, posi, posf, l_mat, m_mat, knode

    integer(ip) :: nvapbi, nvapbj, nnode, i, iface, jprob, l_faci, l_facj, ic


    integer(ip), allocatable :: aux_ia(:)
    type(hash_table_ip_ip_t) :: visited

    if ( iblock == jblock ) then
       if (present(gtype) ) then 
          dof_graph%type = gtype
       else
          dof_graph%type = csr
       end if
    else ! iblock /= jblock
       dof_graph%type = csr
    end if


    touch = 1
    ltype = dof_graph%type
    assert ( ltype == csr_symm .or. ltype == csr )

    ! Initialize
    dof_graph%type = ltype
    dof_graph%nv  = fe_space%ndofs(iblock) ! SB.alert : not stored there anymore
    dof_graph%nv2 = fe_space%ndofs(jblock)
    call memalloc( dof_graph%nv+1, dof_graph%ia, __FILE__,__LINE__ )
    dof_graph%ia = 0

    ! COUNT PART
    call count_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph )
    call count_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph ) 
    call count_nnz_all_dofs_vs_all_dofs_by_face_integration( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph )  

    !
    dof_graph%ia(1) = 1
    do idof = 2, fe_space%ndofs(iblock)+1
       dof_graph%ia(idof) = dof_graph%ia(idof) + dof_graph%ia(idof-1)
    end do

    ! write(*,*) 'DOF_GRAPH%IA'
    ! write(*,*) '****START****'
    ! write(*,*) 'dof_graph%ia',dof_graph%ia
    ! write(*,*) '****END****'

    call memalloc ( dof_graph%ia(fe_space%ndofs(iblock)+1)-1, dof_graph%ja, __FILE__, __LINE__ )

    ! LIST PART

    call memalloc( dof_graph%nv+1, aux_ia, __FILE__,__LINE__ )
    aux_ia = dof_graph%ia

    call list_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia ) 
    call list_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia )
    call list_nnz_all_dofs_vs_all_dofs_by_face_integration( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia ) 

    ! write(*,*) 'DOF_GRAPH%JA'
    ! write(*,*) '****START****'
    ! write(*,*) 'dof_graph%ja',dof_graph%ja
    ! write(*,*) '****END****'

    do idof = 1, fe_space%ndofs(iblock)
       ! Order increasingly column identifiers of current row 
       ! using heap sort algorithm
       posi = dof_graph%ia(idof)
       posf = dof_graph%ia(idof+1)-1
       call sort(posf-posi+1,dof_graph%ja(posi:posf))
    end do

!!$    do idof = 1, fe_space%ndofs(iblock)
!!$       !write (*,*) 'DOFS COUPLED TO IDOF:',idof
!!$       !write (*,*) '****** START:'
!!$       do l_dof = dof_graph%ia(idof),dof_graph%ia(idof+1)-1
!!$          !write(*,'(I5,$)') dof_graph%ja(l_dof)
!!$       end do
!!$       !write (*,*) '****** END'
!!$    end do

    ! call graph_print( 6, dof_graph )

    call memfree (aux_ia,__FILE__,__LINE__)

  end subroutine create_dof_graph_block



  !*********************************************************************************
  ! Count NNZ (number of nonzero entries) for DOFs on the interface (VEFs) of elements against
  ! both interior and interface nodes.
  !*********************************************************************************
  subroutine count_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)                :: dof_graph

    ! Local variables
    type(hash_table_ip_ip_t) :: visited
    integer(ip) :: idof, ielem, inode, iobje, iprob, istat, ivars 
    integer(ip) :: jdof, jelem, job_g, jobje, k_var, l_dof, l_mat
    integer(ip) :: l_node, l_var, m_dof, m_mat, m_var, nvapb, touch, ltype

    ltype = dof_graph%type

    do iobje = 1, trian%num_vefs             
       if ( fe_space%vef2dof(iblock)%p(iobje+1)-fe_space%vef2dof(iblock)%p(iobje) > 0) then
          call visited%init(100) 
          do ielem = 1, trian%vefs(iobje)%num_elems_around
             jelem = trian%vefs(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then
                do jobje = 1, trian%elems(jelem)%num_vefs
                   job_g = trian%elems(jelem)%vefs(jobje)
                   call visited%put(key=job_g, val=touch, stat=istat)
                   if ( istat == now_stored ) then   ! interface-interface
                      do idof = fe_space%vef2dof(iblock)%p(iobje), fe_space%vef2dof(iblock)%p(iobje+1)-1
                         l_dof = fe_space%vef2dof(iblock)%l(idof,1)
                         l_var = fe_space%vef2dof(iblock)%l(idof,2)
                         l_mat = fe_space%vef2dof(iblock)%l(idof,3)
                         do jdof = fe_space%vef2dof(jblock)%p(job_g), fe_space%vef2dof(jblock)%p(job_g+1)-1
                            m_dof = fe_space%vef2dof(jblock)%l(jdof,1)
                            m_var = fe_space%vef2dof(jblock)%l(jdof,2)
                            m_mat = fe_space%vef2dof(jblock)%l(jdof,3)
                            if ( dof_descriptor%dof_coupl(l_var,m_var) == 1 .and. l_mat == m_mat ) then
                               if ( ltype == csr ) then
                                  dof_graph%ia(l_dof+1) = &
                                       & dof_graph%ia(l_dof+1) + 1
                               else ! ltype == csr_symm 
                                  if ( m_dof >= l_dof ) then
                                     dof_graph%ia(l_dof+1) = &
                                          & dof_graph%ia(l_dof+1) + 1
                                  end if
                               end if
                            end if
                         end do
                      end do
                   end if
                end do
                !end do
                if (.not.fe_space%static_condensation) then  ! interface-interior
                   iprob = fe_space%finite_elements(jelem)%problem
                   nvapb = dof_descriptor%prob_block(jblock,iprob)%nd1
                   do idof = fe_space%vef2dof(iblock)%p(iobje), fe_space%vef2dof(iblock)%p(iobje+1)-1
                      l_dof = fe_space%vef2dof(iblock)%l(idof,1)
                      l_var = fe_space%vef2dof(iblock)%l(idof,2)
                      l_mat = fe_space%vef2dof(iblock)%l(idof,3)
                      do ivars = 1, nvapb
                         k_var = dof_descriptor%prob_block(jblock,iprob)%a(ivars)
                         m_var = dof_descriptor%problems(iprob)%p%l2g_var(k_var)
                         m_mat = fe_space%finite_elements(jelem)%continuity(m_var)
                         if ( dof_descriptor%dof_coupl(l_var, m_var) == 1 .and. l_mat == m_mat ) then                
                            if ( ltype == csr ) then
                               dof_graph%ia(l_dof+1) =  dof_graph%ia(l_dof+1) &
                                    & + fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje+1) &
                                    & - fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje)
                            else ! ltype == csr_symm
                               do inode = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje), &
                                    & fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje+1)-1
                                  l_node = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%l(inode)
                                  m_dof = fe_space%finite_elements(jelem)%elem2dof(l_node,k_var)
                                  if ( m_dof >= l_dof ) then
                                     dof_graph%ia(l_dof+1) = &
                                          & dof_graph%ia(l_dof+1) + 1
                                  end if
                               end do
                            end if
                         end if
                      end do
                   end do
                end if
             end if
          end do
          call visited%free
       end if
    end do
  end subroutine count_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity

  !*********************************************************************************
  ! List NNZ (number of nonzero entries) for DOFs on the interface (VEFs) of elements against
  ! both interior and interface nodes.
  !*********************************************************************************
  subroutine list_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)                :: dof_graph
    integer(ip), intent(inout)                :: aux_ia(:)

    ! Local variables
    type(hash_table_ip_ip_t) :: visited
    integer(ip) :: idof, ielem, inode, iobje, iprob, istat, ivars 
    integer(ip) :: jdof, jelem, job_g, jobje, k_var, l_dof, l_mat
    integer(ip) :: l_node, l_var, m_dof, m_mat, m_var, nvapb, touch, ltype, count, ic

    ltype = dof_graph%type

    count = 0
    do iobje = 1, trian%num_vefs 
       if ( fe_space%vef2dof(iblock)%p(iobje+1)-fe_space%vef2dof(iblock)%p(iobje) > 0) then
          call visited%init(100) 
          do ielem = 1, trian%vefs(iobje)%num_elems_around
             jelem = trian%vefs(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then 
                do jobje = 1, trian%elems(jelem)%num_vefs
                   job_g = trian%elems(jelem)%vefs(jobje)
                   call visited%put(key=job_g, val=touch, stat=istat)
                   if ( istat == now_stored ) then  ! interface-interface
                      do idof = fe_space%vef2dof(iblock)%p(iobje), fe_space%vef2dof(iblock)%p(iobje+1)-1
                         l_dof = fe_space%vef2dof(iblock)%l(idof,1)
                         l_var = fe_space%vef2dof(iblock)%l(idof,2)
                         do jdof = fe_space%vef2dof(jblock)%p(job_g), fe_space%vef2dof(jblock)%p(job_g+1)-1
                            m_dof = fe_space%vef2dof(jblock)%l(jdof,1)
                            m_var = fe_space%vef2dof(jblock)%l(jdof,2)
                            if ( dof_descriptor%dof_coupl(l_var,m_var) == 1 ) then
                               if ( ltype == csr ) then
                                  !write(*,*) '************INSERT IN IDOF: ',l_dof,' JDOF: ',m_dof
                                  ic = aux_ia(l_dof)
                                  dof_graph%ja(ic) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof)+1
                               else ! ltype == csr_symm 
                                  if ( m_dof >= l_dof ) then
                                     ic = aux_ia(l_dof)
                                     dof_graph%ja(ic) = m_dof
                                     aux_ia(l_dof) = aux_ia(l_dof)+1
                                  end if
                               end if
                            end if
                         end do
                      end do
                   end if
                end do
                !end do
                if (.not.fe_space%static_condensation) then  ! interface-interior
                   iprob = fe_space%finite_elements(jelem)%problem
                   nvapb = dof_descriptor%prob_block(jblock,iprob)%nd1
                   do idof = fe_space%vef2dof(iblock)%p(iobje), fe_space%vef2dof(iblock)%p(iobje+1)-1
                      l_dof = fe_space%vef2dof(iblock)%l(idof,1)
                      l_var = fe_space%vef2dof(iblock)%l(idof,2)
                      l_mat = fe_space%vef2dof(iblock)%l(idof,3)
                      do ivars = 1, nvapb
                         k_var = dof_descriptor%prob_block(jblock,iprob)%a(ivars)
                         m_var = dof_descriptor%problems(iprob)%p%l2g_var(k_var)
                         m_mat = fe_space%finite_elements(jelem)%continuity(m_var)
                         if ( dof_descriptor%dof_coupl(l_var, m_var) == 1 .and. l_mat == m_mat ) then                
                            if ( ltype == csr ) then
                               do inode = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje), &
                                    & fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje+1)-1
                                  l_node = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%l(inode)
                                  m_dof = fe_space%finite_elements(jelem)%elem2dof(l_node,k_var)
                                     ic = aux_ia(l_dof)
                                     dof_graph%ja(ic) = m_dof
                                     aux_ia(l_dof) = aux_ia(l_dof)+1
                               end do
                            else ! ltype == csr_symm
                               do inode = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje), &
                                    & fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(jobje+1)-1
                                  l_node = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%l(inode)
                                  m_dof = fe_space%finite_elements(jelem)%elem2dof(l_node,k_var)
                                  if ( m_dof >= l_dof ) then
                                     ic = aux_ia(l_dof)
                                     dof_graph%ja(ic) = m_dof
                                     aux_ia(l_dof) = aux_ia(l_dof)+1
                                  end if
                               end do
                            end if
                         end if
                      end do
                   end do
                end if
             end if
          end do
          call visited%free
       end if
    end do

  end subroutine list_nnz_dofs_vefs_vs_dofs_vefs_vol_by_continuity

  !*********************************************************************************
  ! Count NNZ (number of nonzero entries) for DOFs on the interface (VEFs) of elements against
  ! both interior and interface nodes.
  !*********************************************************************************
  subroutine count_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)                :: dof_graph

    ! Local variables
    integer(ip) :: g_var, ielem, inode, int_i, iobje, iprob, ivars, jdof, jnode, job_g
    integer(ip) :: jobje, jvars, k_var, l_dof, l_mat, l_node, l_var, ltype, m_dof, m_mat
    integer(ip) :: m_node, m_var, nvapbi, nvapbj

    ltype = dof_graph%type

    ! As commented for elem2dof, static condensation is false for dG, by construction of the 
    ! fem space.
    if (.not.fe_space%static_condensation) then
       do ielem  = 1, trian%num_elems
          iobje = trian%elems(ielem)%num_vefs+1
          iprob = fe_space%finite_elements(ielem)%problem
          nvapbi = dof_descriptor%prob_block(iblock,iprob)%nd1 
          do ivars = 1, nvapbi
             l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
             g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
             ! Interior - interior 
             nvapbj = dof_descriptor%prob_block(jblock,iprob)%nd1 
             do jvars = 1, nvapbj
                k_var = dof_descriptor%prob_block(jblock,iprob)%a(jvars)
                m_var = dof_descriptor%problems(iprob)%p%l2g_var(k_var)
                if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 ) then
                   do inode = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje), &
                        & fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje+1)-1
                      l_node = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%l(inode)
                      l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                      if ( ltype == csr ) then
                         dof_graph%ia(l_dof+1) =  dof_graph%ia(l_dof+1) &
                              &  + fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje+1) &
                              & - fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje)
                      else ! ltype == csr_symm 
                         do jnode = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje), &
                              & fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje+1)-1
                            m_node = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%l(jnode)
                            m_dof = fe_space%finite_elements(ielem)%elem2dof(m_node,k_var)
                            if ( m_dof >= l_dof ) then
                               dof_graph%ia(l_dof+1) = &
                                    & dof_graph%ia(l_dof+1) + 1
                            end if
                         end do
                      end if
                   end do
                end if
             end do
             l_mat = fe_space%finite_elements(ielem)%continuity(g_var)
             if ( l_mat /= 0 ) then
                ! Interior - interface 
                do jobje = 1, trian%elems(ielem)%num_vefs
                   job_g = trian%elems(ielem)%vefs(jobje)
                   do jdof = fe_space%vef2dof(jblock)%p(job_g), fe_space%vef2dof(jblock)%p(job_g+1)-1
                      m_dof = fe_space%vef2dof(jblock)%l(jdof,1)
                      m_var = fe_space%vef2dof(jblock)%l(jdof,2)   
                      m_mat = fe_space%vef2dof(jblock)%l(jdof,3)                      
                      if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 .and. l_mat == m_mat ) then
                         do inode = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje), &
                              & fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje+1)-1
                            l_node = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%l(inode)
                            l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                            if ( ltype == csr ) then
                               dof_graph%ia(l_dof+1) = &
                                    & dof_graph%ia(l_dof+1) + 1 
                            else if ( m_dof >= l_dof ) then
                               dof_graph%ia(l_dof+1) = &
                                    & dof_graph%ia(l_dof+1) + 1
                            end if
                         end do
                      end if
                   end do
                end do
             end if
          end do
       end do
    end if

  end subroutine count_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity

  !*********************************************************************************
  ! List NNZ (number of nonzero entries) for DOFs on the interface (VEFs) of elements against
  ! both interior and interface nodes.
  !*********************************************************************************
  subroutine list_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)              :: dof_graph
    integer(ip), intent(inout)                  :: aux_ia(:) 

    ! Local variables
    integer(ip) :: g_var, ielem, inode, iobje, iprob, ivars, jdof, jnode, job_g
    integer(ip) :: jobje, jvars, k_var, l_dof, l_mat, l_node, l_var, ltype, m_dof, m_mat
    integer(ip) :: m_node, m_var, nvapbi, nvapbj, i, ic

    ltype = dof_graph%type

    if (.not.fe_space%static_condensation) then   
       do ielem  = 1, trian%num_elems
          iobje = trian%elems(ielem)%num_vefs+1
          iprob = fe_space%finite_elements(ielem)%problem
          nvapbi = dof_descriptor%prob_block(iblock,iprob)%nd1  
          do ivars = 1, nvapbi
             !l_var = g2l(ivars,iprob)
             l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
             g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
             ! Interior - interior (inside element)
             nvapbj = dof_descriptor%prob_block(jblock,iprob)%nd1  
             do jvars = 1, nvapbj
                k_var = dof_descriptor%prob_block(jblock,iprob)%a(jvars)
                m_var = dof_descriptor%problems(iprob)%p%l2g_var(k_var)
                if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 ) then
                   do inode = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje), &
                        & fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje+1)-1
                      l_node = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%l(inode)
                      l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                      if ( ltype == csr ) then
                         do jnode = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje), &
                              & fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje+1)-1
                            m_node = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%l(jnode)
                            m_dof = fe_space%finite_elements(ielem)%elem2dof(m_node,k_var)
                            i= aux_ia(l_dof)
                            dof_graph%ja(i) = m_dof
                            aux_ia(l_dof) = aux_ia(l_dof)+1
                         end do
                      else ! ltype == csr_symm 
                         do jnode = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje), &
                              & fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%p(iobje+1)-1
                            m_node = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%l(jnode)
                            m_dof = fe_space%finite_elements(ielem)%elem2dof(m_node,k_var)
                            if ( m_dof >= l_dof ) then
                               ic = aux_ia(l_dof)
                               dof_graph%ja(ic) = m_dof
                               aux_ia(l_dof) = aux_ia(l_dof)+1
                            end if
                         end do
                      end if
                   end do
                end if
             end do
             if ( fe_space%finite_elements(ielem)%continuity(g_var) /= 0 ) then
                ! Interior - border (inside element)
                do jobje = 1, trian%elems(ielem)%num_vefs
                   job_g = trian%elems(ielem)%vefs(jobje)
                   do jdof = fe_space%vef2dof(jblock)%p(job_g), fe_space%vef2dof(jblock)%p(job_g+1)-1
                      m_dof = fe_space%vef2dof(jblock)%l(jdof,1)
                      m_var = fe_space%vef2dof(jblock)%l(jdof,2)                         
                      if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 ) then
                         do inode = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje), &
                              & fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%p(iobje+1)-1
                            l_node = fe_space%finite_elements(ielem)%nodes_per_vef(l_var)%p%l(inode)
                            l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                            if ( ltype == csr ) then
                               ic = aux_ia(l_dof)
                               dof_graph%ja(ic) = m_dof
                               aux_ia(l_dof) = aux_ia(l_dof)+1
                            else if ( m_dof >= l_dof ) then
                               ic = aux_ia(l_dof)
                               dof_graph%ja(ic) = m_dof
                               aux_ia(l_dof) = aux_ia(l_dof)+1
                            end if
                         end do
                      end if
                   end do
                end do
             end if
          end do
       end do
    end if
  end subroutine list_nnz_dofs_vol_vs_dofs_vefs_vol_by_continuity

  !*********************************************************************************
  ! Count NNZ (number of nonzero entries) for DOFs on the element interior (for dG) being 
  ! coupled due to integration on faces. *** This part requires more ellaboration for cdG
  ! generalization***
  !*********************************************************************************
  ! Note: Here we take a face in which we want to integrate dG terms for pairs of unknowns
  ! and couple all DOFs a la DG. Note that we are not using AT ALL the continuity value,
  ! since the integration in faces is driven by the faces selected for integration, which
  ! are being built accordingly to what one wants to do (cG, dG, dG for jump of cont value, etc.).
  ! One could think that it could happen that two elements K1 and K2 with two different 
  ! values of continuity that share a face where we want to integrate could put more than
  ! once the coupling among two nodes. It can never happen AS SOON AS one never creates
  ! an integration face between two elements with same continuity value (not 0), which is the
  ! expected usage. 
  ! *** We could put an assert about it when creating the integration list.
  !*********************************************************************************
  subroutine count_nnz_all_dofs_vs_all_dofs_by_face_integration ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)              :: dof_graph

    ! Local variables
    integer(ip) :: count, g_var, i, ielem, iface, inode, iobje, iprob, ivars, jelem
    integer(ip) :: jnode, jprob, jvars, k_var, knode, l_dof, l_faci, l_facj, l_node
    integer(ip) :: l_var, ltype, m_dof, m_var, m_node, nnode, nvapbi, nvapbj

    ltype = dof_graph%type

    ! Loop over all interior faces (boundary faces do not include additional coupling)
    do iface = 1,fe_space%num_interior_faces
       iobje = fe_space%interior_faces(iface)%face_vef
       assert ( trian%vefs(iobje)%num_elems_around == 2 ) 
       do i=1,2
          ielem = trian%vefs(iobje)%elems_around(i)
          jelem = trian%vefs(iobje)%elems_around(3-i)
          l_faci = local_position(fe_space%interior_faces(iface)%face_vef,trian%elems(ielem)%vefs, &
               & trian%elems(ielem)%num_vefs )
          l_facj = local_position(fe_space%interior_faces(iface)%face_vef,trian%elems(jelem)%vefs, &
               & trian%elems(jelem)%num_vefs )
          iprob = fe_space%finite_elements(ielem)%problem
          jprob = fe_space%finite_elements(jelem)%problem
          nvapbi = dof_descriptor%prob_block(iblock,iprob)%nd1 
          nvapbj = dof_descriptor%prob_block(iblock,jprob)%nd1 
          do ivars = 1, nvapbi
             l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
             g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
             do jvars = 1, nvapbj
                k_var = dof_descriptor%prob_block(iblock,jprob)%a(jvars)
                m_var = dof_descriptor%problems(jprob)%p%l2g_var(k_var)
                if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 ) then
                   if ( ltype == csr ) then
                      ! Couple all DOFs in ielem with face DOFs in jelem and viceversa (i=1,2)
                      nnode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1) &
                           &  -fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj)
                      do inode = 1, fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%nnode
                         l_dof = fe_space%finite_elements(ielem)%elem2dof(inode,l_var)
                         if ( l_dof /= 0 ) then
                            dof_graph%ia(l_dof+1) = dof_graph%ia(l_dof+1) &
                                 & + nnode
                         end if
                      end do
                      nnode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%nnode - nnode
                      assert ( nnode > 0)
                      ! Couple all face DOFs in ielem with DOFs in jelem NOT in the face and viceversa (i=1,2)
                      do inode = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci), &
                           &     fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci+1)-1
                         l_node = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%l(inode)
                         l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                         if ( l_dof /= 0 ) then
                            dof_graph%ia(l_dof+1) = dof_graph%ia(l_dof+1) &
                                 & + nnode
                         end if
                      end do
                   else ! ltype == csr_symm 
                      ! Couple all DOFs in ielem with face DOFs in jelem and viceversa (i=1,2)
                      do inode = 1, fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%nnode
                         l_dof = fe_space%finite_elements(ielem)%elem2dof(inode,l_var)
                         if ( l_dof /= 0 ) then
                            do jnode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj), &
                                 & fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1
                               m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                               m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)
                               if ( l_dof /= 0 .and. m_dof >= l_dof ) then
                                  dof_graph%ia(l_dof+1) = &
                                       & dof_graph%ia(l_dof+1) + 1
                               end if
                            end do
                         end if
                      end do
                      ! Couple all face DOFs in ielem with DOFs in jelem NOT in the face and viceversa (i=1,2)
                      count = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj)
                      knode = -1
                      if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                         knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                      end if
                      do jnode = 1, fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%nnode
                         if ( jnode == knode) then
                            count = count+1
                            if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                               knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                            end if
                         else
                            m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                            m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)

                            do inode = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci), &
                                 &     fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci+1)-1
                               l_node = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%l(inode)
                               l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                               if ( m_dof >= l_dof ) then
                                  !write (*,*) 'INSERTION DUE TO COUPLING BY FACE(ielem)-INTERIOR(jelem)'
                                  !write (*,*) 'ielem,jelem,iobje,l_faci,l_facj',ielem,jelem,iobje,l_faci,l_facj
                                  !write (*,*) 'ielem,jelem'
                                  !write (*,*) 'IN DOF',l_dof,'BEING COUPLED TO DOF',m_dof
                                  !write (*,*) 'NOW',l_dof,'COUPLED TO',dof_graph%ia(l_dof+1) + 1
                                  !write (*,*) 'CHECK COLISION:count,knode,jnode',count,knode,jnode
                                  dof_graph%ia(l_dof+1) = &
                                       & dof_graph%ia(l_dof+1) + 1
                               end if
                            end do
                         end if
                      end do

                   end if
                end if
             end do
          end do
       end do
    end do
  end subroutine count_nnz_all_dofs_vs_all_dofs_by_face_integration

  !*********************************************************************************
  ! Count NNZ (number of nonzero entries) for DOFs on the element interior (for dG) being 
  ! coupled due to integration on faces. *** This part requires more ellaboration for cdG
  ! generalization***
  !*********************************************************************************
  subroutine list_nnz_all_dofs_vs_all_dofs_by_face_integration ( iblock, jblock, dof_descriptor, trian, fe_space, dof_graph, aux_ia )  
    implicit none
    ! Parameters
    integer(ip), intent(in)                     :: iblock, jblock
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(in)                 :: fe_space 
    type(graph_t), intent(inout)              :: dof_graph
    integer(ip), intent(inout)                  :: aux_ia(:) 

    ! Local variables
    integer(ip) :: count, g_var, i, ielem, iface, inode, iobje, iprob, ivars, jelem
    integer(ip) :: jnode, jprob, jvars, k_var, knode, l_dof, l_faci, l_facj, l_node
    integer(ip) :: l_var, ltype, m_dof, m_var, m_node, nnode, nvapbi, nvapbj, ic

    ltype = dof_graph%type

    ! Loop over all interior faces (boundary faces do not include additional coupling)
    do iface = 1, fe_space%num_interior_faces
       iobje = fe_space%interior_faces(iface)%face_vef
       assert ( trian%vefs(iobje)%num_elems_around == 2 ) 
       do i=1,2
          ielem = trian%vefs(iobje)%elems_around(i)
          jelem = trian%vefs(iobje)%elems_around(3-i)
          l_faci = local_position(iobje,trian%elems(ielem)%vefs, &
               & trian%elems(ielem)%num_vefs )
          l_facj = local_position(iobje,trian%elems(jelem)%vefs, &
               & trian%elems(jelem)%num_vefs )
          iprob = fe_space%finite_elements(ielem)%problem
          jprob = fe_space%finite_elements(jelem)%problem
          nvapbi = dof_descriptor%prob_block(iblock,iprob)%nd1 
          nvapbj = dof_descriptor%prob_block(iblock,jprob)%nd1 
          do ivars = 1, nvapbi
             l_var = dof_descriptor%prob_block(iblock,iprob)%a(ivars)
             g_var = dof_descriptor%problems(iprob)%p%l2g_var(l_var)
             do jvars = 1, nvapbj
                k_var = dof_descriptor%prob_block(iblock,jprob)%a(jvars)
                m_var = dof_descriptor%problems(jprob)%p%l2g_var(k_var)
                if ( dof_descriptor%dof_coupl(g_var,m_var) == 1 ) then
                   if ( ltype == csr ) then
                      ! Couple all DOFs in ielem with face DOFs in jelem and viceversa (i=1,2)
                      do inode = 1, fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%nnode
                         l_dof = fe_space%finite_elements(ielem)%elem2dof(inode,l_var)
                         if ( l_dof /= 0 ) then 
                            !                         do jnode = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(l_facj), &
                            !                              &     fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%p(l_facj+1)-1 
                            !                            m_node = fe_space%finite_elements(ielem)%nodes_per_vef(k_var)%p%l(jnode)
                            do jnode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj), &
                                 & fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1
                               m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                               !                            m_node = fe_space%finite_elements(jelem)%nodes_per_vef(k_var)%p%l(jnode)
                               m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)
                               ic = aux_ia(l_dof)
                               dof_graph%ja(ic) = m_dof
                               aux_ia(l_dof) = aux_ia(l_dof) + 1
                            end do
                         end if
                      end do
                      ! Couple all face DOFs in ielem with DOFs in jelem NOT in the face and viceversa (i=1,2)
                      count = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj)
                      knode = -1
                      if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                         knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                      end if
                      do jnode = 1, fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%nnode
                         if ( jnode == knode) then
                            count = count+1
                            if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                               knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                            end if
                         else
                            m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                            m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)
                            do inode = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci), &
                                 &     fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci+1)-1
                               l_node = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%l(inode)
                               l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                               if (l_dof /= 0 ) then
                                  ic = aux_ia(l_dof)
                                  dof_graph%ja(ic) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof) + 1
                               end if
                            end do
                         end if
                      end do
                   else ! ltype == csr_symm 
                      ! Couple all DOFs in ielem with face DOFs in jelem and viceversa (i=1,2)
                      do inode = 1, fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%nnode
                         l_dof = fe_space%finite_elements(ielem)%elem2dof(inode,l_var)
                         if (l_dof /= 0 ) then
                            do jnode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj), &
                                 & fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1
                               m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                               m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)
                               if ( m_dof >= l_dof ) then
                                  !write (*,*) 'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
                                  !write (*,*) 'INSERTION DUE TO COUPLING BY (ielem)-FACE(jelem)'
                                  !write (*,*) 'IN DOF',l_dof,'BEING COUPLED TO DOF',m_dof
                                  !write (*,*) 'IN POSITION',aux_ia(l_dof)
                                  !write (*,*) 'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV'
                                  ic = aux_ia(l_dof)
                                  dof_graph%ja(ic) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof) + 1
                               end if
                            end do
                         END if
                      end do
                      ! Couple all face DOFs in ielem with DOFs in jelem NOT in the face and viceversa (i=1,2)
                      count = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj)
                      knode = -1
                      if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                         knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                      end if
                      do jnode = 1, fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%nnode
                         if ( jnode == knode) then
                            count = count+1
                            if (count <= fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%p(l_facj+1)-1) then
                               knode = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(count)
                            end if
                         else
                            m_node = fe_space%finite_elements(jelem)%reference_element_vars(k_var)%p%ntxob%l(jnode)
                            m_dof = fe_space%finite_elements(jelem)%elem2dof(m_node,k_var)
                            do inode = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci), &
                                 &     fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%p(l_faci+1)-1
                               l_node = fe_space%finite_elements(ielem)%reference_element_vars(l_var)%p%ntxob%l(inode)
                               l_dof = fe_space%finite_elements(ielem)%elem2dof(l_node,l_var)
                               if ( l_dof /= 0 .and. m_dof >= l_dof ) then
                                  !write (*,*) 'KKKKKKKKKKKKKK'
                                  !write (*,*) 'INSERTION DUE TO COUPLING BY FACE(ielem)-INTERIOR(jelem)'
                                  !write (*,*) 'IN DOF',l_dof,'BEING COUPLED TO DOF',m_dof
                                  !write (*,*) 'IN POSITION',aux_ia(l_dof)
                                  !write (*,*) 'KKKKKKKKKKKKKK'
                                  ic = aux_ia(l_dof)
                                  dof_graph%ja(ic) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof) + 1
                               end if
                            end do
                         end if
                      end do
                   end if
                end if
             end do
          end do
       end do
    end do

  end subroutine list_nnz_all_dofs_vs_all_dofs_by_face_integration

  !*********************************************************************************
  ! Auxiliary function that generates new DOFs and put them in a particular VEF of a given element
  !*********************************************************************************
  subroutine put_new_vefs_dofs_in_vef_of_element ( dof_descriptor, trian, fe_space, g_var, jelem, l_var, &
       count, obje_l )
    implicit none
    ! Parameters
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(inout)              :: fe_space 
    integer(ip), intent(inout)                  :: count
    integer(ip), intent(in)                     :: g_var, jelem, l_var, obje_l

    ! Local variables
    integer(ip) :: inode, l_node

    do inode = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l), &
         &     fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l+1)-1 
       l_node = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%l(inode)
       count = count + 1
       !write (*,*) '****PUT DOF**** (elem,obj_l,obj_g,node,idof) ',jelem,obje_l,iobje,l_node,count
       fe_space%finite_elements(jelem)%elem2dof(l_node,l_var) = count
    end do

  end subroutine put_new_vefs_dofs_in_vef_of_element

  !*********************************************************************************
  ! Auxiliary function that puts existing DOFs in a particular VEF of a given element
  !*********************************************************************************
  subroutine put_existing_vefs_dofs_in_vef_of_element ( dof_descriptor, trian, fe_space, touch, mater, g_var, iobje, jelem, l_var, &
       o2n, obje_l )
    implicit none
    ! Parameters
    type(dof_descriptor_t), intent(in)               :: dof_descriptor
    type(triangulation_t), intent(in)         :: trian 
    type(fe_space_t), intent(inout)              :: fe_space
    integer(ip), intent(in)                     :: touch(:,:,:), mater, g_var, iobje, jelem, l_var, obje_l
    integer(ip), intent(out)                    :: o2n(:)

    ! Local variables
    integer(ip) :: elem_ext, obje_ext, prob_ext, l_var_ext
    integer(ip) :: nnode, order, inode, l_node, inode_ext, inode_l

    elem_ext = touch(mater,g_var,1)
    obje_ext = touch(mater,g_var,2)
    prob_ext = fe_space%finite_elements(elem_ext)%problem
    l_var_ext = dof_descriptor%g2l_vars(g_var,prob_ext)
    !write (*,*) '****EXTRACT DOF**** (object)', iobje, ' FROM: (elem,obj_l) ',elem_ext,obje_ext, ' TO  : (elem,obj_l)', jelem,obje_l
    assert ( l_var_ext > 0 )
    nnode = fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%p(obje_ext+1) &
         &  -fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%p(obje_ext) 
    if ( nnode > 0) then  
       order = fe_space%finite_elements(elem_ext)%reference_element_vars(l_var_ext)%p%order
       if ( trian%vefs(iobje)%dimension == trian%num_dims .and. &
            & nnode ==  (order+1)**trian%num_dims ) then
          order = order    ! hdG case
       elseif ( nnode ==  (order-1)**trian%vefs(iobje)%dimension ) then
          order = order -2 ! cG case
       else
          assert ( 0 == 1) ! SB.alert : Other situations possible when dG_continuity, cdG, hp-adaptivity ?
       end if
       call permute_nodes_per_vef(                                                                 &
            & fe_space%finite_elements(elem_ext)%reference_element_vars(l_var_ext)%p,                                           &
            & fe_space%finite_elements(jelem)%reference_element_vars(l_var)%p,                                                  &
            & o2n,obje_ext,obje_l,                                                                &
            & trian%elems(elem_ext)%vefs,                                                      &
            & trian%elems(jelem)%vefs,                                                         &
            & trian%vefs(iobje)%dimension,                                                     &
            & order )
       do inode = 1, fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%p(obje_ext+1) - &
            fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%p(obje_ext)
          l_node = fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%p(obje_ext) + inode - 1
          inode_ext = fe_space%finite_elements(elem_ext)%nodes_per_vef(l_var_ext)%p%l(l_node )
          l_node = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%p(obje_l) + o2n(inode) - 1
          inode_l = fe_space%finite_elements(jelem)%nodes_per_vef(l_var)%p%l(l_node)
          fe_space%finite_elements(jelem)%elem2dof(inode_l,l_var) = fe_space%finite_elements(elem_ext)%elem2dof(inode_ext,l_var_ext)
       end do ! SB.alert : 1) face object for cG and hdG, where the face must have all their nodes
       !                   2) corner / edge only for cG
       !            * Never here for dG, continuity interface, hanging objects, etc.


    end if
  end subroutine put_existing_vefs_dofs_in_vef_of_element

  !*********************************************************************************
  ! Auxiliary function that returns the position of key in list
  !*********************************************************************************
  integer(ip) function local_position(key,list,size)
    implicit none
    integer(ip) :: key, size, list(size)

    do local_position = 1,size
       if ( list(local_position) == key) exit
    end do
    assert ( local_position < size + 1 )

  end function local_position



end module create_global_dof_info_names
