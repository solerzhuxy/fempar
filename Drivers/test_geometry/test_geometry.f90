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
program test_geometry

use fempar_names
use test_geometry_params

implicit none
    type(geometry_t)      :: geometry
    type(line_t), pointer :: line
    type(point_t)         :: point
    real(rp)              :: param
    !real(rp)              :: point(3),param

    character(len=str_cla_len)       :: dir_path, dir_path_out
    character(len=str_cla_len)       :: prefix, filename
    integer(ip)                      :: lunio, istat
    type(parameterlist_t), pointer   :: parameterlist
    type(test_geometry_params_t)     :: test_params

    call FEMPAR_INIT()

    call test_params%create()
    parameterlist => test_params%get_parameters()
    call geometry%read(parameterlist)

    call FEMPAR_FINALIZE()

end program test_geometry
