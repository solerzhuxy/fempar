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
program test_operators
  use serial_names
  implicit none
#include "debug.i90"
  
  type(serial_scalar_matrix_t)    :: Mat
  type(serial_scalar_array_t)     :: Vec1
  type(serial_scalar_array_t)     :: Vec2
  type(dynamic_state_operator_t)  :: Op
  
  call meminit
  
  call Mat%create(symmetric_storage=.false., is_symmetric=.false., sign=unknown)
  ! Begin External Process which creates the graph of Mat
  Mat%graph%nv  = 3
  Mat%graph%nv2 = 3
  call memalloc ( Mat%graph%nv+1, Mat%graph%ia, __FILE__, __LINE__)
  Mat%graph%ia = (/1,3,5,7/)
  call memalloc ( Mat%graph%ia(Mat%graph%nv+1)-1, Mat%graph%ja, __FILE__, __LINE__)
  Mat%graph%ja = (/1,3,1,2,1,3/)
  ! End External Process which creates the graph of Mat
  call Mat%allocate()
  Mat%a = (/1.0,3.0,1.0,2.0,1.0,3.0/)
  
  call Vec1%create_and_allocate(Mat%graph%nv)
  call Vec2%create_and_allocate(Mat%graph%nv)
  call Vec1%init(1.0_rp)
    
  Op = Mat + Mat
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)

  Op = Mat - Mat
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)
  
  Op = Mat * Mat 
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)
  
  Op = -Mat
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)

  Op = 3.0*Mat
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)
  
  Op = Mat*3.0 
  call Op%apply(Vec1,Vec2)
  call Vec2%print(6)
  
  call Mat%free()
  call Vec1%free()
  call Vec2%free()
  call Op%free()
  
  call memstatus
  
end program test_operators
