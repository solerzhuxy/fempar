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
  use types
  use array_names
  use memor
  use fem_triangulation_names
  use fem_space_names
  use dof_handler_names
  use fem_space_types
  use hash_table_names
  use fem_graph_names
  use sort_names
  implicit none
# include "debug.i90"
  private

  public :: create_global_dof_info

contains
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  subroutine create_global_dof_info ( dhand, trian, femsp, dof_graph ) ! graph
    implicit none
    ! Parameters
    type(dof_handler), intent(in)             :: dhand
    type(fem_triangulation), intent(in)       :: trian 
    type(fem_space), intent(inout)            :: femsp 
    type(fem_graph), allocatable, intent(out) :: dof_graph(:,:) 

    ! Local variables
    integer(ip) :: iprob, l_var, iblock, count, iobje, ielem, jelem, nvapb, ivars, g_var, inter
    integer(ip) :: obje_l, inode, l_node, elem_ext, obje_ext, prob_ext, l_var_ext, inter_ext, inode_ext, inode_l
    integer(ip) :: mater, order, nnode
    integer(ip) :: g2l_vars(dhand%nvars_global,dhand%nprobs), touch(femsp%num_materials,dhand%nvars_global,2),touch_g(dhand%nvars_global)

    type(array_ip1) :: prob_block(dhand%nblocks,dhand%nprobs)
    integer(ip)     :: ndofs(dhand%nblocks),o2n(max_nnode)!SB.alert (max_nnode) just to check

    integer(ip) :: gtype, idof, jdof, int_i, int_j, istat, jblock, jnode, job_g, jobje, jvars, k_var, l_dof, m_dof, m_node, m_var, posi, posf

    integer(ip), allocatable :: aux_ia(:)

    type(hash_table_ip_ip) :: visited

!    type(list_2d)  :: object2dof

    ! Global to local of variables per problem

    do iprob = 1, dhand%nprobs
       do l_var = 1, dhand%problems(iprob)%nvars
          g2l_vars( dhand%problems(iprob)%l2g_var(l_var), iprob) = l_var
       end do
    end do

    ! Create elem2dof and obj2dof
    do iblock = 1, dhand%nblocks  

       ! variables of a given problem for current block (prob_block)
       do iprob = 1, dhand%nprobs
          count = 0
          do l_var = 1, dhand%problems(iprob)%nvars
             if ( dhand%vars_block(dhand%problems(iprob)%l2g_var(l_var)) == iblock ) then
                count = count + 1 
             end if
          end do
          call array_create( count, prob_block(iblock,iprob))
          count = 0 
          do l_var = 1, dhand%problems(iprob)%nvars
             if ( dhand%vars_block(dhand%problems(iprob)%l2g_var(l_var)) == iblock ) then
                count = count + 1 
                prob_block(iblock,iprob)%a(count) = l_var!dhand%problems(iprob)%l2g_var(l_var)
             end if
          end do
       end do

    end do

    do iblock = 1, dhand%nblocks  
       count = 0
       ! interface
       do iobje = 1, trian%num_objects
          touch = 0
          do ielem = 1, trian%objects(iobje)%num_elems_around
             jelem = trian%objects(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then 
                iprob = femsp%lelem(jelem)%problem
                nvapb = prob_block(iblock,iprob)%nd1
                do ivars = 1, nvapb
                   !l_var = g2l(ivars,iprob)
                   l_var = prob_block(iblock,iprob)%a(ivars)
                   g_var = dhand%problems(iprob)%l2g_var(l_var)
                   inter = l_var
                   mater = femsp%lelem(jelem)%material ! SB.alert : material can be used as p 
                   do obje_l = 1, trian%elems(jelem)%num_objects
                      if ( trian%elems(jelem)%objects(obje_l) == iobje ) exit
                   end do
                   if ( touch(mater,g_var,1) == 0) then
                      touch(mater,g_var,1) = jelem
                      touch(mater,g_var,2) = obje_l
                      !do inode = 1, femsp%lelem(jelem)%nodes_object(inter,obje_l)%nd1
                      do inode = femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l), &
                           &     femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l+1)-1 
                         l_node = femsp%lelem(jelem)%nodes_object(inter)%p%l(inode)
                         !femsp%lelem(jelem)%nodes_object(inter,obje_l)%a(inode)
                         count = count + 1

                         write (*,*) '****PUT DOF**** (elem,obj_l,obj_g,node,idof) ',jelem,obje_l,iobje,l_node,count

                         femsp%lelem(jelem)%elem2dof(l_node,l_var) = count
                      end do
                   else
                      elem_ext = touch(mater,g_var,1)
                      obje_ext = touch(mater,g_var,2)
                      prob_ext = femsp%lelem(elem_ext)%problem
                      l_var_ext = g2l_vars(g_var,prob_ext)

                      write (*,*) '****EXTRACT DOF**** (object)', iobje, ' FROM: (elem,obj_l) ',elem_ext,obje_ext, ' TO  : (elem,obj_l)', jelem,obje_l

                      assert ( l_var_ext > 0 )
                      inter_ext = l_var_ext

                      nnode = femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext+1) &
                           &  -femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext) 

                      !write (*,*) 'nnode',nnode
                      !write (*,*) 'trian%objects(iobje)%dimension ',trian%objects(iobje)%dimension
                      !write (*,*) '(order-1)**trian%objects(iobje)%dimension ',(order-1)**trian%objects(iobje)%dimension 


                      if ( nnode ==  (order-1)**trian%objects(iobje)%dimension ) then
                         !write (*,*) 'nnode XXX',nnode ! cG case
                      end if
                      if ( nnode > 0) then  
                         order = femsp%lelem(elem_ext)%f_inf(inter_ext)%p%order
                         !write (*,*) 'order',order
                         if ( trian%objects(iobje)%dimension == trian%num_dims .and. &
                              & nnode ==  (order+1)**trian%num_dims ) then
                            order = order    ! hdG case
                         elseif ( nnode ==  (order-1)**trian%objects(iobje)%dimension ) then
                            order = order -2 ! cG case
                         else
                            assert ( 0 == 1) ! SB.alert : Other situations possible when dG_material, cdG, hp-adaptivity ?
                         end if

                         !write (*,*) 'order',order

                         call permute_nodes_object(                                                                 &
                              & femsp%lelem(elem_ext)%f_inf(inter_ext)%p,                                           &
                              & femsp%lelem(jelem)%f_inf(inter)%p,                                                  &
                              & o2n,obje_ext,obje_l,                                                                &
                              & trian%elems(elem_ext)%objects,                                                      &
                              & trian%elems(jelem)%objects,                                                         &
                              & trian%objects(iobje)%dimension,                                                     &
                              & order )

                         !write (*,*) 'PERMUTATION ARRAY:',o2n, '*'
                         ! do inode_ext = femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext), &
                         !      &         femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext+1)-1
                         !    inode_l = femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext) &
                         !         &    + femsp%lelem(jelem)%nodes_object(inter)%p%l(o2n(inode_ext))-1
                         do inode = 1, femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext+1) - &
                              femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext)
                            l_node = femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%p(obje_ext) + inode - 1
                            inode_ext = femsp%lelem(elem_ext)%nodes_object(inter_ext)%p%l(l_node )
                            l_node = femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l) + o2n(inode) - 1
                            inode_l = femsp%lelem(jelem)%nodes_object(inter)%p%l(l_node)
                            !inode_l = femsp%lelem(jelem)%nodes_object(inter,obje_l)%a(o2n(inode_ext))
                            write (*,*) '****COPY FROM NODE: ',inode_ext,' TO NODE: ',inode_l, 'DOF', &
                                 & femsp%lelem(elem_ext)%elem2dof(inode_ext,l_var_ext)
                            femsp%lelem(jelem)%elem2dof(inode_l,l_var) = femsp%lelem(elem_ext)%elem2dof(inode_ext,l_var_ext)
                         end do ! SB.alert : 1) face object for cG and hdG, where the face must have all their nodes
                         !                   2) corner / edge only for cG
                         !            * Never here for dG, material interface, hanging objects, etc.
                      end if
                   end if
                end do
             end if
          end do
       end do

       ! interior
       if ( .not. femsp%static_condensation ) then 
          do ielem = 1, trian%num_elems
             iprob = femsp%lelem(ielem)%problem
             nvapb = prob_block(iblock,iprob)%nd1
             do ivars = 1, nvapb
                l_var = prob_block(iblock,iprob)%a(ivars)
                g_var = dhand%problems(iprob)%l2g_var(l_var)  
                iobje = trian%elems(ielem)%num_objects+1
                do inode = femsp%lelem(ielem)%nodes_object(inter)%p%p(iobje), &
                     &     femsp%lelem(ielem)%nodes_object(inter)%p%p(iobje+1)-1 
                   l_node = femsp%lelem(ielem)%nodes_object(inter)%p%l(inode)
                   !l_node = femsp%lelem(ielem)%nodes_object(inter,iobje)%a(inode)
                   count = count +1
                   femsp%lelem(ielem)%elem2dof(l_node,l_var) = count
                end do
             end do
          end do
       end if

       ndofs(iblock) = count

       write (*,*) 'NDOFS:',ndofs(iblock)
    end do


    call fem_space_print( 6, femsp )

    !assert ( 0 == 1)

    do iblock = 1, dhand%nblocks  

       ! Create object to dof

       !call memalloc ( dhand%nvars_global, touch, __FILE__, __LINE__ ) 
       femsp%object2dof%n = trian%num_objects
       call memalloc ( trian%num_objects+1, femsp%object2dof%p, __FILE__, __LINE__ )
       do iobje = 1, trian%num_objects
          touch_g = 0
          do ielem = 1, trian%objects(iobje)%num_elems_around
             jelem = trian%objects(iobje)%elems_around(ielem)
             if ( jelem <= trian%num_elems ) then 
                nvapb = prob_block(iblock,iprob)%nd1
                !write(*,*) 'nvapb:',nvapb
                do ivars = 1, nvapb
                   l_var = prob_block(iblock,iprob)%a(ivars)
                   g_var = dhand%problems(iprob)%l2g_var(l_var)
                   if ( touch_g(g_var) == 0 ) then
                      touch_g(g_var) = 1
                      inter = l_var
                      do obje_l = 1, trian%elems(jelem)%num_objects
                         if ( trian%elems(jelem)%objects(obje_l) == iobje ) exit
                      end do
                      !write (*,*) 'ADD TO OBJECT',iobje,' #DOFS',femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l+1) &
                      ! & - femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l)
                      femsp%object2dof%p(iobje+1) = femsp%object2dof%p(iobje+1) + femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l+1) &
                           & - femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l)
                      !do inode = 1, femsp%lelem(jelem)%nodes_object(inter)%p%(iobje+1) - &
                      !     & femsp%lelem(jelem)%nodes_object(inter)%p%(iobje)
                      !femsp%object2dof%p(iobje+1) = femsp%object2dof%p(iobje+1) + femsp%lelem(jelem)%nodes_object(inter)%p%(iobje)%nd1
                      !end do
                   end if
                end do
             end if
          end do
       end do
       !call memfree( touch, __FILE__, __LINE__ )
       !
       !write (*,*) 'femsp%object2dof%p', femsp%object2dof%p
       femsp%object2dof%p(1) = 1
       do iobje = 2, trian%num_objects+1
          femsp%object2dof%p(iobje) = femsp%object2dof%p(iobje) + femsp%object2dof%p(iobje-1)
       end do
       !write (*,*) 'femsp%object2dof%p', femsp%object2dof%p
       !write (*,*) 'femsp%object2dof%p(trian%num_objects+1)-1',femsp%object2dof%p(trian%num_objects+1)-1
       call memalloc ( femsp%object2dof%p(trian%num_objects+1)-1, 2, femsp%object2dof%l, __FILE__, __LINE__ )
       ! 
       touch_g = 0
       count = 0
       do iobje = 1, trian%num_objects
          touch_g = 0
          do ielem = 1, trian%objects(iobje)%num_elems_around
             jelem = trian%objects(iobje)%elems_around(ielem)
             nvapb = prob_block(iblock,iprob)%nd1
             do ivars = 1, nvapb
                l_var = prob_block(iblock,iprob)%a(ivars)
                g_var = dhand%problems(iprob)%l2g_var(l_var)
                if ( touch_g(g_var) == 0 ) then
                   touch_g(g_var) = 1
                   inter = l_var
                   do obje_l = 1, trian%elems(jelem)%num_objects
                      if ( trian%elems(jelem)%objects(obje_l) == iobje ) exit
                   end do
                   do inode = femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l), &
                        &     femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l+1)-1 

                      !1, femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l+1) - &
                      !                        & femsp%lelem(jelem)%nodes_object(inter)%p%p(obje_l)
                      l_node = femsp%lelem(jelem)%nodes_object(inter)%p%l(inode)
                      count = count + 1
                      femsp%object2dof%l(count,1) = femsp%lelem(jelem)%elem2dof(l_node,l_var)
                      femsp%object2dof%l(count,2) = dhand%problems(iprob)%l2g_var(l_var)
                   end do
                end if
             end do
          end do
       end do
       write (*,*) 'femsp%object2dof%p', femsp%object2dof%p
       write (*,*) 'femsp%object2dof%l', femsp%object2dof%l
    end do

    ! Create graph
    allocate( dof_graph(dhand%nblocks,dhand%nblocks), stat = istat )
    check( istat == 0)

    ! Point to mesh's parallel partition object
    do iblock=1,dhand%nblocks
       do jblock=1,dhand%nblocks
          if ( iblock == jblock ) then
             dof_graph(iblock,jblock)%type = csr !SB.alert: to be considered ... gtype(iblock)
          else ! ibloc /= jbloc
             dof_graph(iblock,jblock)%type = csr
          end if
       end do
    end do


    do iblock = 1,dhand%nblocks
       do jblock = 1,dhand%nblocks
          gtype = dof_graph(iblock,jblock)%type
          assert ( gtype == csr_symm .or. gtype == csr )

          ! Initialize
          dof_graph(iblock,jblock)%type = gtype
          dof_graph(iblock,jblock)%nv  = ndofs(iblock) ! SB.alert : not stored there anymore
          dof_graph(iblock,jblock)%nv2 = ndofs(jblock)
          call memalloc( dof_graph(iblock,jblock)%nv+1, dof_graph(iblock,jblock)%ia, __FILE__,__LINE__ )
          dof_graph(iblock,jblock)%ia = 0

          ! COUNT

          do iobje = 1, trian%num_objects             
             if ( femsp%object2dof%p(iobje+1)-femsp%object2dof%p(iobje) > 0) then
                call visited%init(100) 
                do ielem = 1, trian%objects(iobje)%num_elems_around
                   jelem = trian%objects(iobje)%elems_around(ielem)
                   if ( jelem <= trian%num_elems ) then 
                      do jobje = 1, trian%elems(jelem)%num_objects
                         job_g = trian%elems(jelem)%objects(jobje)
                         !write (*,*) 'job_g',job_g
                         call visited%put(key=job_g, val=1, stat=istat)
                         !write (*,*) 'istat',istat
                         if ( istat == now_stored ) then
                            do idof = femsp%object2dof%p(iobje), femsp%object2dof%p(iobje+1)-1
                               l_dof = femsp%object2dof%l(idof,1)
                               l_var = femsp%object2dof%l(idof,2)
                               do jdof = femsp%object2dof%p(job_g), femsp%object2dof%p(job_g+1)-1
                                  m_dof = femsp%object2dof%l(jdof,1)
                                  m_var = femsp%object2dof%l(jdof,2)
                                  if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                                     if ( gtype == csr ) then
                                        dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                             & dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                                     else ! gtype == csr_symm 
                                        if ( m_dof >= l_dof ) then
                                           dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                                & dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                                        end if
                                     end if
                                  end if
                               end do
                            end do
                         end if
                      end do
                      !end do
                      if (.not.femsp%static_condensation) then
                         ! jobje = jobje 
                         iprob = femsp%lelem(jelem)%problem
                         do idof = femsp%object2dof%p(iobje), femsp%object2dof%p(iobje+1)-1
                            l_dof = femsp%object2dof%l(idof,1)
                            l_var = femsp%object2dof%l(idof,2)
                            nvapb = prob_block(iblock,iprob)%nd1
                            do ivars = 1, nvapb
                               k_var = prob_block(iblock,iprob)%a(ivars)
                               m_var = dhand%problems(iprob)%l2g_var(k_var)
                               inter = l_var
                               ! do ivars = 1, dhand%problems(femsp%lelem(jelem)%problem)%nvars
                               if ( dhand%dof_coupl(l_var, m_var) == 1 ) then                
                                  if ( gtype == csr ) then
                                     dof_graph(iblock,jblock)%ia(l_dof+1) =  dof_graph(iblock,jblock)%ia(l_dof+1) &
                                          & + femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje+1) &
                                          & - femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje)
                                  else ! gtype == csr_symm
                                     do inode = femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje), &
                                          & femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje+1)-1
                                        l_node = femsp%lelem(jelem)%nodes_object(inter)%p%l(inode)
                                        m_dof = femsp%lelem(jelem)%elem2dof(l_node,m_var)
                                        if ( m_dof >= l_dof ) then
                                           dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                                & dof_graph(iblock,jblock)%ia(l_dof+1) + 1
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
          ! Interior nodes
          if (.not.femsp%static_condensation) then   
             do ielem  = 1, trian%num_elems
                iobje = trian%elems(ielem)%num_objects+1
                iprob = femsp%lelem(ielem)%problem
                nvapb = prob_block(iblock,iprob)%nd1  
                do ivars = 1, nvapb
                   !l_var = g2l(ivars,iprob)
                   l_var = prob_block(iblock,iprob)%a(ivars)
                   g_var = dhand%problems(iprob)%l2g_var(l_var)
                   int_i = l_var
                   ! Interior - interior (inside element)
                   do jvars = 1, nvapb
                      m_var = prob_block(iblock,iprob)%a(jvars)
                      g_var = dhand%problems(iprob)%l2g_var(m_var)
                      if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                         int_j = m_var
                         do inode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                              & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                            l_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(inode)
                            l_dof = femsp%lelem(ielem)%elem2dof(l_node,l_var)
                            if ( gtype == csr ) then
                               dof_graph(iblock,jblock)%ia(l_dof+1) =  dof_graph(iblock,jblock)%ia(l_dof+1) &
                                    &  + femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1) &
                                    & - femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje)
                            else ! gtype == csr_symm 
                               do jnode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                                    & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                                  m_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(jnode)
                                  m_dof = femsp%lelem(ielem)%elem2dof(m_node,m_var)
                                  if ( m_dof >= l_dof ) then
                                     dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                          & dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                                  end if
                               end do
                            end if
                         end do
                      end if
                   end do
                   ! Interior - border (inside element)
                   do jobje = 1, trian%elems(ielem)%num_objects
                      job_g = trian%elems(ielem)%objects(jobje)
                      do jdof = femsp%object2dof%p(job_g), femsp%object2dof%p(job_g+1)-1
                         m_dof = femsp%object2dof%l(jdof,1)
                         m_var = femsp%object2dof%l(jdof,2)                         
                         if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                            do inode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                                 & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                               l_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(inode)
                               l_dof = femsp%lelem(ielem)%elem2dof(l_node,l_var)
                               if ( gtype == csr ) then
                                  dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                       & dof_graph(iblock,jblock)%ia(l_dof+1) + 1 
                               else if ( m_dof >= l_dof ) then
                                  dof_graph(iblock,jblock)%ia(l_dof+1) = &
                                       & dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                               end if
                            end do
                         end if
                      end do
                   end do
                end do
             end do
          end if

          !
          dof_graph(iblock,jblock)%ia(1) = 1
          do idof = 2, ndofs(iblock)+1
             dof_graph(iblock,jblock)%ia(idof) = dof_graph(iblock,jblock)%ia(idof) + dof_graph(iblock,jblock)%ia(idof-1)
          end do

          call memalloc ( dof_graph(iblock,jblock)%ia(ndofs(iblock)+1)-1, dof_graph(iblock,jblock)%ja, __FILE__, __LINE__ )

          ! LIST
          call memalloc( dof_graph(iblock,jblock)%nv+1, aux_ia, __FILE__,__LINE__ )
          aux_ia = dof_graph(iblock,jblock)%ia

          write(*,*) 'graph%ia : ',dof_graph(iblock,jblock)%ia

          write(*,*) '******* LIST *******'
          count = 0
          do iobje = 1, trian%num_objects 
             write(*,*) 'LOOP OBJECTS **** IOBJE:',iobje    
             if ( femsp%object2dof%p(iobje+1)-femsp%object2dof%p(iobje) > 0) then
                call visited%init(100) 
                do ielem = 1, trian%objects(iobje)%num_elems_around
                   jelem = trian%objects(iobje)%elems_around(ielem)
                   write(*,*) '**** LOOP ELEMENTS CONTAIN OBJECT **** ELEM:',jelem
                   if ( jelem <= trian%num_elems ) then 
                      do jobje = 1, trian%elems(jelem)%num_objects
                         job_g = trian%elems(jelem)%objects(jobje)
                         !write (*,*) 'job_g',job_g
                         call visited%put(key=job_g, val=1, stat=istat)
                         !write (*,*) 'istat',istat
                         if ( istat == now_stored ) then
                            write(*,*) '******** LOOP  OBJECTS IN ELEM **** JOBJE:',job_g
                            do idof = femsp%object2dof%p(iobje), femsp%object2dof%p(iobje+1)-1
                               l_dof = femsp%object2dof%l(idof,1)
                               l_var = femsp%object2dof%l(idof,2)
                               do jdof = femsp%object2dof%p(job_g), femsp%object2dof%p(job_g+1)-1
                                  m_dof = femsp%object2dof%l(jdof,1)
                                  m_var = femsp%object2dof%l(jdof,2)
                                  if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                                     if ( gtype == csr ) then
                                        write(*,*) '************INSERT IN IDOF: ',l_dof,' JDOF: ',m_dof
                                        count = aux_ia(l_dof)
                                        dof_graph(iblock,jblock)%ja(count) = m_dof
                                        aux_ia(l_dof) = aux_ia(l_dof)+1
                                        !& dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                                     else ! gtype == csr_symm 
                                        if ( m_dof >= l_dof ) then
                                           count = aux_ia(l_dof)
                                           dof_graph(iblock,jblock)%ja(count) = m_dof
                                           aux_ia(l_dof) = aux_ia(l_dof)+1
                                           !& dof_graph(iblock,jblock)%ia(l_dof+1) + 1
                                        end if
                                     end if
                                  end if
                               end do
                            end do
                         end if
                      end do
                      !end do
                      if (.not.femsp%static_condensation) then
                         ! jobje = jobje 
                         iprob = femsp%lelem(jelem)%problem
                         do idof = femsp%object2dof%p(iobje), femsp%object2dof%p(iobje+1)-1
                            l_dof = femsp%object2dof%l(idof,1)
                            l_var = femsp%object2dof%l(idof,2)
                            nvapb = prob_block(iblock,iprob)%nd1
                            do ivars = 1, nvapb
                               k_var = prob_block(iblock,iprob)%a(ivars)
                               m_var = dhand%problems(iprob)%l2g_var(k_var)
                               inter = l_var
                               ! do ivars = 1, dhand%problems(femsp%lelem(jelem)%problem)%nvars
                               if ( dhand%dof_coupl(l_var, m_var) == 1 ) then                
                                  if ( gtype == csr ) then
                                     do inode = femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje), &
                                          & femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje+1)-1
                                        l_node = femsp%lelem(jelem)%nodes_object(inter)%p%l(inode)
                                        m_dof = femsp%lelem(jelem)%elem2dof(l_node,m_var)
                                        count = aux_ia(l_dof)
                                        dof_graph(iblock,jblock)%ja(count) = m_dof
                                        aux_ia(l_dof) = aux_ia(l_dof)+1
                                     end do
                                  else ! gtype == csr_symm
                                     do inode = femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje), &
                                          & femsp%lelem(jelem)%nodes_object(inter)%p%p(jobje+1)-1
                                        l_node = femsp%lelem(jelem)%nodes_object(inter)%p%l(inode)
                                        m_dof = femsp%lelem(jelem)%elem2dof(l_node,m_var)
                                        if ( m_dof >= l_dof ) then
                                           count = aux_ia(l_dof)
                                           dof_graph(iblock,jblock)%ja(count) = m_dof
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
          ! Interior nodes
          if (.not.femsp%static_condensation) then   
             do ielem  = 1, trian%num_elems
                iobje = trian%elems(ielem)%num_objects+1
                iprob = femsp%lelem(ielem)%problem
                nvapb = prob_block(iblock,iprob)%nd1  
                do ivars = 1, nvapb
                   !l_var = g2l(ivars,iprob)
                   l_var = prob_block(iblock,iprob)%a(ivars)
                   g_var = dhand%problems(iprob)%l2g_var(l_var)
                   int_i = l_var
                   ! Interior - interior (inside element)
                   do jvars = 1, nvapb
                      m_var = prob_block(iblock,iprob)%a(jvars)
                      g_var = dhand%problems(iprob)%l2g_var(m_var)
                      if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                         int_j = m_var
                         do inode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                              & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                            l_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(inode)
                            l_dof = femsp%lelem(ielem)%elem2dof(l_node,l_var)
                            if ( gtype == csr ) then
                               do jnode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                                    & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                                  m_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(jnode)
                                  m_dof = femsp%lelem(ielem)%elem2dof(m_node,m_var)
                                  count = aux_ia(l_dof)
                                  dof_graph(iblock,jblock)%ja(count) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof)+1
                               end do
                            else ! gtype == csr_symm 
                               do jnode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                                    & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                                  m_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(jnode)
                                  m_dof = femsp%lelem(ielem)%elem2dof(m_node,m_var)
                                  if ( m_dof >= l_dof ) then
                                     count = aux_ia(l_dof)
                                     dof_graph(iblock,jblock)%ja(count) = m_dof
                                     aux_ia(l_dof) = aux_ia(l_dof)+1
                                  end if
                               end do
                            end if
                         end do
                      end if
                   end do
                   ! Interior - border (inside element)
                   do jobje = 1, trian%elems(ielem)%num_objects
                      job_g = trian%elems(ielem)%objects(jobje)
                      do jdof = femsp%object2dof%p(job_g), femsp%object2dof%p(job_g+1)-1
                         m_dof = femsp%object2dof%l(jdof,1)
                         m_var = femsp%object2dof%l(jdof,2)                         
                         if ( dhand%dof_coupl(l_var,m_var) == 1 ) then
                            do inode = femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje), &
                                 & femsp%lelem(ielem)%nodes_object(int_i)%p%p(iobje+1)-1
                               l_node = femsp%lelem(ielem)%nodes_object(int_i)%p%l(inode)
                               l_dof = femsp%lelem(ielem)%elem2dof(l_node,l_var)
                               if ( gtype == csr ) then
                                  count = aux_ia(l_dof)
                                  dof_graph(iblock,jblock)%ja(count) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof)+1
                               else if ( m_dof >= l_dof ) then
                                  count = aux_ia(l_dof)
                                  dof_graph(iblock,jblock)%ja(count) = m_dof
                                  aux_ia(l_dof) = aux_ia(l_dof)+1
                               end if
                            end do
                         end if
                      end do
                   end do
                end do
             end do
          end if



          do idof = 1, ndofs(iblock)
             ! Order increasingly column identifiers of current row 
             ! using heap sort algorithm
             posi = dof_graph(iblock,jblock)%ia(idof)
             posf = dof_graph(iblock,jblock)%ia(idof+1)-1
             call sort(posf-posi+1,dof_graph(iblock,jblock)%ja(posi:posf))
          end do
          do idof = 1, ndofs(iblock)
             write (*,*) 'DOFS COUPLED TO IDOF:',idof
             write (*,*) '****** START:'
             do l_dof = dof_graph(iblock,jblock)%ia(idof),dof_graph(iblock,jblock)%ia(idof+1)-1
                write(*,'(I5,$)') dof_graph(iblock,jblock)%ja(l_dof)
             end do
             write (*,*) '****** END'
          end do
          !call fem_graph_print( 6, dof_graph(iblock,jblock) )
          call memfree (aux_ia,__FILE__,__LINE__)
       end do
    end do

    ! TO BE DONE IN THE NEAR FUTURE FOR DG THINGS (SB.alert)
    !    ! Interface nodes coupling via face integration
    !    if (dg) then
    !       do iface = 1,nface
    !          do other element in face
    !             couple with nodes on that face () BOTH DIRECTIONS
    !          end do
    !       end do
    !    end if
    ! end do

  end subroutine create_global_dof_info

   end module create_global_dof_info_names
