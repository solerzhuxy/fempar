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
module problem_names
  use types
  use memor
  implicit none
  private

  type physical_problem
     integer(ip)        ::             &
          nvars,                       &       ! Number of different variables
          nunks,                       &       ! Number of unknowns (groups of variables)
          ndime,                       &       ! Number of space dimensions
          ntens                                ! Number of tensor components
     integer(ip), allocatable ::       &
          vars_of_unk(:),              &       ! Number of variables of each unknown (size nunks)
          l2g_var(:)                           ! Order chosen for variables (size nvars)
     integer(ip)        ::             &
          problem_code                         ! An internal code that defines a problem in FEMPAR
     character(len=:), allocatable ::  &
          unkno_names(:)                       ! Names for the gauss_properties (nunks)

  end type physical_problem

public :: physical_problem

end module problem_names