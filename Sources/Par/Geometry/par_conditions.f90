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
module par_conditions_names
  ! Serial modules
  use types
  use memor
  use stdio
  use renum_names
  use fem_conditions_names
  use fem_conditions_io

  ! Parallel modules
  use par_environment_names
  use par_io

# include "debug.i90"
  implicit none
  private

  type par_conditions
     ! Data structure which stores the local part
     ! of the BC's mapped to the current processor
     type(fem_conditions) :: f_conditions

     ! Parallel environment control
     type(par_environment), pointer :: p_env => NULL()
  end type par_conditions

  ! Types
  public :: par_conditions

  ! Methods
  public :: par_conditions_create, par_conditions_free     , & 
            par_conditions_copy, par_conditions_apply_renum, &
            par_conditions_read

contains

  !===============================================================================================
  subroutine par_conditions_create(ncode,nvalu,ncond,p_env,cnd)
    implicit none
    integer(ip)                  , intent(in)    :: ncode, nvalu, ncond
    type(par_environment), target, intent(in)    :: p_env
    type(par_conditions)         , intent(inout) :: cnd

    ! Parallel environment MUST BE already created
    assert ( p_env%created )

    cnd%p_env => p_env

    if( p_env%p_context%iam >= 0 ) then
       call fem_conditions_create ( ncode,nvalu,ncond,cnd%f_conditions)
    end if

  end subroutine par_conditions_create

  !===============================================================================================
  subroutine par_conditions_copy(cnd_old,cnd_new)
    implicit none
    type(par_conditions), target, intent(in)    :: cnd_old
    type(par_conditions)        , intent(inout) :: cnd_new

    ! Parallel environment MUST BE already created
    assert ( cnd_old%p_env%created )
    
    cnd_new%p_env => cnd_old%p_env

    if( cnd_new%p_env%p_context%iam >= 0 ) then
       call fem_conditions_copy ( cnd_old%f_conditions, cnd_new%f_conditions )
    end if

  end subroutine par_conditions_copy

  !===============================================================================================
  subroutine par_conditions_apply_renum(ren, cnd)
    implicit none
    type(renum)         ,    intent(in)  :: ren
    type(par_conditions), intent(inout)  :: cnd
    
    ! Parallel environment MUST BE already created
    assert ( cnd%p_env%created )
    
    if( cnd%p_env%p_context%iam >= 0 ) then
       call fem_conditions_apply_renum ( ren, cnd%f_conditions )
    end if

  end subroutine par_conditions_apply_renum

  !===============================================================================================
  subroutine par_conditions_free(cnd)
    implicit none
    type(par_conditions), intent(inout) :: cnd

    ! Parallel environment MUST BE already created
    assert ( cnd%p_env%created )
    
    if( cnd%p_env%p_context%iam >= 0 ) then
       call fem_conditions_free ( cnd%f_conditions )
    end if
    
  end subroutine par_conditions_free

  !=============================================================================
  subroutine par_conditions_read ( dir_path, prefix, npoin, p_env, p_conditions )
    implicit none 
    ! Parameters
    character (*)                , intent(in)  :: dir_path
    character (*)                , intent(in)  :: prefix
    integer(ip)                  , intent(in)  :: npoin
    type(par_environment), target, intent(in)  :: p_env
    type(par_conditions)         , intent(out) :: p_conditions
    
    ! Locals
    character(len=:), allocatable  :: name
    integer(ip) :: lunio
    
    ! Parallel environment MUST BE already created
    assert ( p_env%created )
    
    p_conditions%p_env => p_env
    if(p_env%p_context%iam>=0) then
       call fem_conditions_compose_name ( prefix, name )
       call par_filename( p_conditions%p_env%p_context, name )
       
       ! Read conditions
       lunio = io_open( trim(dir_path) // '/' // trim(name), 'read' )
       call fem_conditions_read_file ( lunio, npoin, p_conditions%f_conditions )
       call io_close(lunio)
    end if
    
  end subroutine par_conditions_read
  
end module par_conditions_names