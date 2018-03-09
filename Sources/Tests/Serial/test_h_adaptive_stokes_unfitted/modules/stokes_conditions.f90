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
module stokes_conditions_names
  use fempar_names
  
  implicit none
# include "debug.i90"
  private
  type, extends(conditions_t) :: stokes_conditions_t
     private
     integer(ip)                       :: num_dims = -1
     class(scalar_function_t), pointer :: boundary_function_p
     type(vector_component_function_t) :: boundary_function_x
     type(vector_component_function_t) :: boundary_function_y
     type(vector_component_function_t) :: boundary_function_z
   contains
     procedure :: set_num_dims                => stokes_conditions_set_num_dims
     procedure :: set_boundary_function       => stokes_conditions_set_boundary_function
     procedure :: get_num_components          => stokes_conditions_get_num_components  
     procedure :: get_components_code         => stokes_conditions_get_components_code
     procedure :: get_function                => stokes_conditions_get_function
  end type stokes_conditions_t
  
  public :: stokes_conditions_t
  
contains

  subroutine stokes_conditions_set_num_dims(this,num_dims)
    implicit none
    class(stokes_conditions_t)      , intent(inout) :: this
    integer(ip) :: num_dims
    this%num_dims = num_dims
  end subroutine stokes_conditions_set_num_dims

  subroutine stokes_conditions_set_boundary_function (this, boundary_function_u, boundary_function_p)
    implicit none
    class(stokes_conditions_t)      , intent(inout) :: this
    class(vector_function_t), target, intent(in) :: boundary_function_u
    class(scalar_function_t), target, intent(in) :: boundary_function_p
    this%boundary_function_p => boundary_function_p
    call this%boundary_function_x%set(boundary_function_u,1)
    call this%boundary_function_y%set(boundary_function_u,2)
    call this%boundary_function_z%set(boundary_function_u,3)
  end subroutine stokes_conditions_set_boundary_function

  function stokes_conditions_get_num_components(this)
    implicit none
    class(stokes_conditions_t), intent(in) :: this
    integer(ip) :: stokes_conditions_get_num_components
    assert(this%num_dims == 2 .or. this%num_dims == 3)
    stokes_conditions_get_num_components = this%num_dims + 1
  end function stokes_conditions_get_num_components

  subroutine stokes_conditions_get_components_code(this, boundary_id, components_code)
    implicit none
    class(stokes_conditions_t), intent(in)  :: this
    integer(ip)            , intent(in)  :: boundary_id
    logical                , intent(out) :: components_code(:)
    assert(this%num_dims == 2 .or. this%num_dims == 3)
    assert ( size(components_code) >= this%num_dims + 1 )
    components_code(:) = .false.
    if (boundary_id >= 1) then
      components_code(1:this%num_dims) = .true.
    end if
    if ( boundary_id == 2 ) then
       components_code(this%num_dims+1) = .true.
    end if
  end subroutine stokes_conditions_get_components_code
  
  subroutine stokes_conditions_get_function ( this, boundary_id, component_id, function )
    implicit none
    class(stokes_conditions_t), target, intent(in)  :: this
    integer(ip)                        , intent(in)  :: boundary_id
    integer(ip)                        , intent(in)  :: component_id
    class(scalar_function_t), pointer  , intent(out) :: function
    assert(associated(this%boundary_function_p))
    nullify(function)
    if ( boundary_id >= 1 ) then
       if(this%num_dims==2) then
          select case ( component_id )
          case (1)
             function => this%boundary_function_x
          case (2)
             function => this%boundary_function_y
          case (3)
             function => this%boundary_function_p
          case default
             check(.false.)
          end select
       else if(this%num_dims==3) then
          select case ( component_id )
          case (1)
             function => this%boundary_function_x
          case (2)
             function => this%boundary_function_y
          case (3)
             function => this%boundary_function_z
          case (4)
             function => this%boundary_function_p
          case default
             check(.false.)
          end select
       else
          check(.false.)
       end if
    end if
  end subroutine stokes_conditions_get_function 

end module stokes_conditions_names
