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
module integration_names
  use types_names
  use assembly_names
  use integrable_names
  use problem_names
  use integration_tools_names
  use femap_interp_names
  use fe_space_names
  use assembly_names
  use block_matrix_names
  use matrix_names
  use block_vector_names
  use vector_names
  use finite_element_names
  use dof_descriptor_names
  implicit none
  private

  ! Abstract assembly interface
  abstract interface
     subroutine assembly_interface(finite_element, dof_descriptor, a)
       import :: finite_element_t, dof_descriptor_t, integrable_t
       implicit none
       type(finite_element_t), intent(in)    :: finite_element
       type(dof_descriptor_t), intent(in)    :: dof_descriptor
       class(integrable_t)   , intent(inout) :: a
     end subroutine assembly_interface
  end interface

  public :: volume_integral

contains

  subroutine volume_integral(approx,fe_space,res1,res2,alternative_assembly)
    implicit none
    ! Parameters
    type(fe_space_t)                    , intent(inout) :: fe_space
    class(integrable_t)                 , intent(inout) :: res1
    class(integrable_t), optional       , intent(inout) :: res2
    type(discrete_integration_pointer_t), intent(inout) :: approx(:)
    procedure(assembly_interface)       , optional      :: alternative_assembly

    ! Locals
    integer(ip) :: ielem,ivar,nvars, current_approximation
    !class(discrete_problem) , pointer :: discrete

    ! Main element loop
    do ielem=1,fe_space%g_trian%num_elems

       nvars = fe_space%finite_elements(ielem)%num_vars
       ! Compute integration tools on ielem for each ivar (they all share the quadrature inside integ)
       do ivar=1,nvars
          call volume_integrator_update(fe_space%finite_elements(ielem)%integ(ivar)%p,fe_space%g_trian%elems(ielem)%coordinates)
       end do
       
       current_approximation = fe_space%finite_elements(ielem)%approximation
       call approx(current_approximation)%p%compute(fe_space%finite_elements(ielem))

       ! Assembly first contribution
       if(present(alternative_assembly)) then
          call alternative_assembly(fe_space%finite_elements(ielem),fe_space%dof_descriptor,res1) 
       else
          call assembly(fe_space%finite_elements(ielem),fe_space%dof_descriptor,res1) 
       end if

       if(present(res2)) then
          if(present(alternative_assembly)) then
             call alternative_assembly(fe_space%finite_elements(ielem),fe_space%dof_descriptor,res2) 
          else
             call assembly(fe_space%finite_elements(ielem),fe_space%dof_descriptor,res2)
          end if
       end if
 
    end do

  end subroutine volume_integral

end module integration_names