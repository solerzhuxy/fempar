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
module block_operator_names
  use types
  use memor
  use base_operator_names
  use base_operand_names

  use block_operand_names

#ifdef memcheck
  use iso_c_binding
#endif

  implicit none
  private

  ! Pointer to operator
  type p_abs_operator
     type(abs_operator), pointer :: p_op => null()
  end type p_abs_operator

  ! Block operator
  type, extends(base_operator) :: block_operator
     private
     integer(ip)                       :: nblocks, mblocks
     type(p_abs_operator), allocatable :: blocks(:,:)
   contains
     procedure  :: apply          => block_operator_apply
     procedure  :: apply_fun      => block_operator_apply_fun
     procedure  :: free           => block_operator_free_tbp
     procedure  :: info           => block_operator_info
     procedure  :: am_i_fine_task => block_operator_am_i_fine_task
     procedure  :: bcast          => block_operator_bcast
  end type block_operator


  ! Types
  public :: block_operator

  ! Functions
  ! public :: 

contains

  ! op%apply(x,y) <=> y <- op*x
  ! Implicitly assumes that y is already allocated
  subroutine block_operator_apply (op,x,y)
    implicit none
    class(block_operator)     , intent(in)   :: op
    class(base_operand)      , intent(in)    :: x
    class(base_operand)      , intent(inout) :: y

    ! Locals
    integer(ip) :: iblk, jblk
    class(base_operand), allocatable :: aux

    call x%GuardTemp()

    select type(x)
    class is (block_operand)
       select type(y)
       class is(block_operand)
          allocate(aux, mold=y%blocks(1)%p_op)
          do iblk=1, op%mblocks
             call y%blocks(iblk)%p_op%init(0.0_rp)
             call aux%clone(y%blocks(iblk)%p_op)
             do jblk=1, op%nblocks
                if (associated(op%blocks(iblk,jblk)%p_op)) then
                    call op%blocks(iblk,jblk)%p_op%apply(x%blocks(jblk)%p_op,aux)
                    call y%blocks(iblk)%p_op%axpby(1.0,aux,1.0)
                 end if
              end do
             call aux%free()
          end do
          call deallocate(aux)
       class default
          write(0,'(a)') 'block_operand%apply: unsupported y class'
          check(1==0)
       end select
    class default
       write(0,'(a)') 'block_operand%apply: unsupported x class'
       check(1==0)
    end select

    call x%CleanTemp()

  end subroutine block_operator_apply

  ! op%apply(x)
  ! Allocates room for (temporary) y
  function block_operator_apply_fun(op,x) result(y)
    implicit none
    class(block_operator), intent(in)  :: op
    class(base_operand) , intent(in)   :: x
    class(base_operand) , allocatable  :: y

    type(block_operand), allocatable :: local_y
    class(base_operand), allocatable :: aux
    integer(ip)                      :: iblk, jblk, first_block_in_row

    select type(x)
    class is (block_operand)
       allocate(local_y)
       call block_operand_alloc(op%mblocks, local_y)
       allocate(aux, mold=x%blocks(1)%p_op)
       do iblk=1, op%mblocks
          first_block_in_row = 1
          do jblk=1, op%nblocks
             if (associated(op%blocks(iblk,jblk)%p_op)) then
                if ( first_block_in_row == 1 ) then
                   aux = op%blocks(iblk,jblk)%p_op * x%blocks(jblk)%p_op
                   allocate(local_y%blocks(iblk)%p_op, mold=aux)
                   local_y%blocks(iblk)%allocated = .true.
                   call local_y%blocks(iblk)%p_op%clone(aux)
                   call local_y%blocks(iblk)%p_op%copy(aux)
                   first_block_in_row = 0
                else
                   call op%blocks(iblk,jblk)%p_op%apply(x%blocks(jblk)%p_op,aux)
                   call local_y%blocks(iblk)%p_op%axpby(1.0,aux,1.0)
                end if
             end if
          end do
          call aux%free()
       end do
       call deallocate(aux)
       call move_alloc(local_y, y)
       call y%SetTemp()
    class default
       write(0,'(a)') 'block_operand%apply_fun: unsupported x class'
       check(1==0)
    end select
  end function block_operator_apply_fun

  subroutine block_operator_free_tbp(this)
    implicit none
    class(block_operator), intent(inout) :: this
  end subroutine block_operator_free_tbp

  subroutine block_operator_info(op,me,np)
    implicit none
    class(block_operator), intent(in)    :: op
    integer(ip)        , intent(out)   :: me
    integer(ip)        , intent(out)   :: np

    ! Locals
    integer(ip) :: iblk, jblk
    
    do jblk=1, op%nblocks
       do iblk=1, op%mblocks
          if (associated(op%blocks(iblk,jblk)%p_op)) then
             call op%blocks(iblk,jblk)%p_op%info(me,np)
             return
          end if
       end do
    end do
    ! At least one block of op MUST be associated
    check(1==0)
  end subroutine block_operator_info

  function block_operator_am_i_fine_task(op)
    implicit none
    class(block_operator), intent(in)    :: op
    logical :: block_operator_am_i_fine_task

    ! Locals
    integer(ip) :: iblk, jblk
    
    do jblk=1, op%nblocks
       do iblk=1, op%mblocks
          if (associated(op%blocks(iblk,jblk)%p_op)) then
             block_operator_am_i_fine_task = op%blocks(iblk,jblk)%p_op%am_i_fine_task()
             return
          end if
       end do
    end do

    ! At least one block of op MUST be associated
    check(1==0)
  end function block_operator_am_i_fine_task

  subroutine block_operator_bcast(op,condition)
    implicit none
    class(block_operator), intent(in)    :: op
    logical            , intent(inout)   :: condition

    ! Locals
    integer(ip) :: iblk, jblk

    do jblk=1, op%nblocks
       do iblk=1, op%mblocks
          if (associated(op%blocks(iblk,jblk)%p_op)) then
             call op%blocks(iblk,jblk)%p_op%bcast(condition)
             return
          end if
       end do
    end do

    ! At least one block of op MUST be associated
    check(1==0)
  end subroutine block_operator_bcast

  subroutine block_operator_alloc (mblocks, nblocks, bop)
    implicit none
    ! Parameters
    integer(ip)             , intent(in)  :: mblocks, nblocks
    type(block_operator)    , intent(out) :: bop
    
    ! Locals
    integer(ip) :: iblk, jblk

    bop%nblocks = nblocks
    bop%mblocks = mblocks
    allocate ( bop%blocks(mblocks,nblocks) )
    do jblk=1, nblocks
       do iblk=1, mblocks
          call block_operator_set_block_to_zero(iblk, jblk, bop)
       end do
    end do
          
  end subroutine block_operator_alloc


  subroutine block_operator_set_block (ib, jb, op, bop)
    implicit none
    ! Parameters
    integer(ip)                         , intent(in)    :: ib, jb
    type(abs_operator)                  , intent(in)    :: op 
    type(block_operator)                , intent(inout) :: bop

    call op%GuardTemp()
    if ( .not. associated(bop%blocks(ib,jb)%p_op) ) then
       allocate(bop%blocks(ib,jb)%p_op)
    end if
    bop%blocks(ib,jb)%p_op = op
    call op%CleanTemp()

  end subroutine block_operator_set_block

  subroutine block_operator_set_block_to_zero (ib, jb, bop)
    implicit none
    ! Parameters
    integer(ip)             , intent(in)    :: ib,jb
    type(block_operator)    , intent(inout) :: bop
    
    if (associated(bop%blocks(ib,jb)%p_op)) then
       call bop%blocks(ib,jb)%p_op%free()
       deallocate(bop%blocks(ib,jb)%p_op)
    end if
    
    nullify ( bop%blocks(ib,jb)%p_op )
  end subroutine block_operator_set_block_to_zero


  subroutine block_operator_free (bop)
    implicit none
    type(block_operator), intent(inout) :: bop

    ! Locals
    integer(ip) :: iblk, jblk
    
    do jblk=1, bop%nblocks
       do iblk=1, bop%mblocks
          if (associated(bop%blocks(iblk,jblk)%p_op)) then
             call bop%blocks(iblk,jblk)%p_op%free()
             deallocate(bop%blocks(iblk,jblk)%p_op)
          end if
       end do
    end do
    bop%nblocks = 0
    bop%mblocks = 0
    deallocate ( bop%blocks )
  end subroutine block_operator_free





end module block_operator_names
