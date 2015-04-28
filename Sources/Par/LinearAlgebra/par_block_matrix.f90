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
module par_block_matrix_names
  ! Serial modules
  use types
  use memor
  use fem_block_matrix_names

  ! Parallel modules
  use par_matrix_names
  use par_vector_names
  use par_block_vector_names

  implicit none
# include "debug.i90"

  private

  !=============================================================
  ! TO-CONSIDER:
  ! x Support for this parallel data structure in integrate.i90 
  !   would eliminate f_blk_matrix member of par_block_matrix and 
  !   par_block_matrix_fill_complete method
  !=============================================================

  ! Pointer to matrix
  type p_par_matrix
    type(par_matrix), pointer :: p_p_matrix
  end type p_par_matrix


  ! Block Matrix
  type par_block_matrix
    integer(ip)                     :: nblocks
    type(p_par_matrix), allocatable :: blocks(:,:)

     ! **IMPORTANT NOTE**: This is an auxiliary data 
     ! structure provided in order to use SERIAL 
     ! fem_block_matrix assembly routines. The blocks of this 
     ! data structure are just VIEWS to the corresponding 
     ! counterparts in type(p_par_matrix), allocatable :: blocks(:).
     ! This is required because currently integrate.i90 only
     ! accepts fem* data structures. If we provided support for 
     ! par* data structures in integrate.i90 we would not require 
     ! this aux. data structure
     type(fem_block_matrix)        :: f_blk_matrix
     logical                       :: fill_completed
  end type par_block_matrix

  ! Types
  public :: par_block_matrix

  ! Functions
  public :: par_block_matrix_alloc, par_block_matrix_alloc_block,       & 
            par_block_matrix_set_block_to_zero, par_block_matrix_print, & 
            par_block_matrix_fill_complete,                             &
            par_block_matrix_free,                                      & 
            par_block_matrix_zero, &
            par_block_matvec

contains

  !=============================================================================
  subroutine par_block_matrix_alloc (nblocks, bmat)
    implicit none
    ! Parameters
    integer(ip)           , intent(in)  :: nblocks
    type(par_block_matrix), intent(out) :: bmat
    integer(ip)                         :: ib,jb

    bmat%nblocks = nblocks
    allocate ( bmat%blocks(nblocks,nblocks) )
    do ib=1, nblocks
      do jb=1, nblocks
           allocate ( bmat%blocks(ib,jb)%p_p_matrix )
      end do
    end do
    bmat%fill_completed = .false.
  end subroutine par_block_matrix_alloc

  subroutine par_block_matrix_alloc_block (ib,jb,bmat)
    implicit none
    ! Parameters
    integer(ip)                   , intent(in)    :: ib,jb
    type(par_block_matrix), target, intent(inout) :: bmat

    if ( .not. associated( bmat%blocks(ib,jb)%p_p_matrix)) then
       allocate ( bmat%blocks(ib,jb)%p_p_matrix )
       if ( bmat%fill_completed ) then
           bmat%f_blk_matrix%blocks(ib,jb)%p_f_matrix => bmat%blocks(ib,jb)%p_p_matrix%f_matrix
       end if
    end if
  end subroutine par_block_matrix_alloc_block

  subroutine par_block_matrix_set_block_to_zero (ib,jb,bmat)
    implicit none
    ! Parameters
    integer(ip)           , intent(in)  :: ib,jb
    type(par_block_matrix), intent(inout) :: bmat

    if ( associated(bmat%blocks(ib,jb)%p_p_matrix) ) then
       deallocate (bmat%blocks(ib,jb)%p_p_matrix)
       nullify    (bmat%blocks(ib,jb)%p_p_matrix)
       if ( bmat%fill_completed ) then
           nullify( bmat%f_blk_matrix%blocks(ib,jb)%p_f_matrix )
       end if
    end if

  end subroutine par_block_matrix_set_block_to_zero

  !=============================================================================
  subroutine par_block_matrix_fill_complete (bmat)
    implicit none
    ! Parameters
    type(par_block_matrix), target, intent(inout) :: bmat
    
    ! Locals
    integer(ip) :: ib,jb  
  
    assert ( .not. bmat%fill_completed )
  
    bmat%f_blk_matrix%nblocks = bmat%nblocks
    allocate ( bmat%f_blk_matrix%blocks(bmat%nblocks,bmat%nblocks) )

    do ib=1, bmat%nblocks
      do jb=1, bmat%nblocks
         if ( associated(bmat%blocks(ib,jb)%p_p_matrix) ) then
            bmat%f_blk_matrix%blocks(ib,jb)%p_f_matrix => bmat%blocks(ib,jb)%p_p_matrix%f_matrix
         else
            nullify (bmat%f_blk_matrix%blocks(ib,jb)%p_f_matrix)
         end if
      end do
    end do

    bmat%fill_completed = .true.
  end subroutine par_block_matrix_fill_complete

  subroutine par_block_matrix_print (lunou, p_b_matrix)
    implicit none
    type(par_block_matrix), intent(in)    :: p_b_matrix
    integer(ip)           , intent(in)    :: lunou
    integer(ip)                           :: i

    check(.false.)
  end subroutine par_block_matrix_print

  !=============================================================================
  subroutine par_block_matrix_free (p_b_matrix)
    implicit none
    type(par_block_matrix), intent(inout) :: p_b_matrix
    integer(ip) :: ib,jb

    do ib=1, p_b_matrix%nblocks
       do jb=1, p_b_matrix%nblocks
          if ( associated(p_b_matrix%blocks(ib,jb)%p_p_matrix) ) then
             deallocate (p_b_matrix%blocks(ib,jb)%p_p_matrix) 
          end if
       end do
    end do

    p_b_matrix%nblocks = 0
    deallocate ( p_b_matrix%blocks )
  
    if ( p_b_matrix%fill_completed ) then
      p_b_matrix%f_blk_matrix%nblocks = 0  
      deallocate( p_b_matrix%f_blk_matrix%blocks ) 
      p_b_matrix%fill_completed = .false.
    end if 
  end subroutine par_block_matrix_free

  !=============================================================================
  subroutine par_block_matrix_zero(bmat)
    implicit none
    ! Parameters
    type(par_block_matrix), intent(inout) :: bmat

    ! Locals
    integer(ip) :: ib, jb
    do ib=1, bmat%nblocks
      do jb=1, bmat%nblocks
         if ( associated(bmat%blocks(ib,jb)%p_p_matrix) ) then
            call par_matrix_zero (bmat%blocks(ib,jb)%p_p_matrix)
         end if
      end do
   end do

  end subroutine par_block_matrix_zero

  subroutine par_block_matvec (a, x, y)
    implicit none
    ! Parameters
    type(par_block_matrix), intent(in)    :: a
    type(par_block_vector), intent(in)    :: x
    type(par_block_vector), intent(inout) :: y

    ! Locals
    type(par_vector)       :: aux
    integer(ip)            :: ib, jb

    assert ( a%nblocks == x%nblocks )
    assert ( a%nblocks == y%nblocks )     


    do ib=1, a%nblocks
       y%blocks(ib)%state = part_summed
       call par_vector_zero  ( y%blocks(ib) )
       call par_vector_clone ( y%blocks(ib), aux ) 
       do jb=1, a%nblocks
          if ( associated(a%blocks(ib,jb)%p_p_matrix) ) then
             ! aux <- A(ib,jb) * x(jb)
             call par_matvec ( a%blocks(ib,jb)%p_p_matrix, x%blocks(jb), aux ) 

             !write (*,*) 'XXXX', ib, '   ', jb                  ! DBG:
             !call fem_vector_print ( 6, y%blocks(ib)%f_vector ) ! DBG:

             ! y(ib) <- y(ib) + aux 
             call par_vector_pxpy ( aux, y%blocks(ib) )

             ! write (*,*) 'XXXX', ib, '   ', jb                 ! DBG:
             !call fem_vector_print ( 6, y%blocks(ib)%f_vector ) ! DBG: 

          end if
       end do
       call par_vector_free ( aux )
    end do
  end subroutine par_block_matvec

end module par_block_matrix_names
