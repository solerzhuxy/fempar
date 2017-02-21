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

module serial_unfitted_triangulation_names
  use fempar_names
  use level_set_functions_gallery_names
  USE IR_Precision ! VTK_IO
  USE Lib_VTK_IO ! VTK_IO
  
  implicit none
# include "debug.i90"
  private

  ! Include the look-up tables 
# include "mc_tables_qua4.i90"
# include "mc_tables_hex8.i90"
  

  type, extends(cell_accessor_t) :: unfitted_cell_accessor_t
  
    private
    class(serial_unfitted_triangulation_t), pointer     :: serial_unfitted_triangulation => NULL()
    type(point_t), pointer :: subcells_phys_coords(:) => NULL()
    integer(ip)  , pointer :: subcells_connectivities(:,:) => NULL()
    type(quadrature_t)  :: quadrature ! TODO who frees this?
    type(fe_map_t)      :: fe_map ! TODO who frees this?  Who deallocates the member variables of a derived type that goes out of scope?
    
  contains
    
    ! Public TBPs
    procedure :: cell_accessor_create         => unfitted_cell_accessor_cell_accessor_create
    procedure :: cell_accessor_free           => unfitted_cell_accessor_cell_accessor_free
    procedure :: cell_accessor_next           => unfitted_cell_accessor_cell_accessor_next
    procedure, non_overridable :: get_number_of_subcells       => unfitted_cell_accessor_get_number_of_subcells
    procedure, non_overridable :: get_number_of_subcell_nodes  => unfitted_cell_accessor_get_number_of_subcell_nodes
    procedure, non_overridable :: get_phys_coords_of_subcell   => unfitted_cell_accessor_get_phys_coords_of_subcell
    procedure, non_overridable :: is_cut => unfitted_cell_accessor_is_cut
    procedure, non_overridable :: is_interior => unfitted_cell_accessor_is_interior
    procedure, non_overridable :: is_exterior => unfitted_cell_accessor_is_exterior    
    
    ! Private TBPs
    procedure, non_overridable, private :: init_private   => cell_accessor_init_private
    procedure, non_overridable, private :: update_private => cell_accessor_update_private
    
  end type unfitted_cell_accessor_t

  type :: unfitted_cell_iterator_t
    private
    type(unfitted_cell_accessor_t) :: current_cell_accessor
  contains
    procedure, non_overridable, private :: create       => unfitted_cell_iterator_create
    procedure, non_overridable          :: free         => unfitted_cell_iterator_free
    procedure, non_overridable          :: init         => unfitted_cell_iterator_init
    procedure, non_overridable          :: next         => unfitted_cell_iterator_next
    procedure, non_overridable          :: has_finished => unfitted_cell_iterator_has_finished
    procedure, non_overridable          :: current      => unfitted_cell_iterator_current
  end type unfitted_cell_iterator_t

  type, extends(serial_triangulation_t) :: serial_unfitted_triangulation_t
    private
    
    ! The level set funciton
    class(level_set_function_t), pointer :: level_set_function

    ! Look up-tables (precomputed off-line, for each cell type)
    integer(ip)                :: mc_table_num_cases
    integer(ip)                :: mc_table_max_num_subcells
    integer(ip)                :: mc_table_max_num_cut_edges
    integer(ip)                :: mc_table_num_nodes_subcell
    integer(ip),   allocatable :: mc_table_num_subcells_per_case(:)
    integer(ip),   allocatable :: mc_table_num_cut_edges_per_case(:)
    integer(ip),   allocatable :: mc_table_inout_subcells_per_case(:,:)
    integer(ip),   allocatable :: mc_table_subcell_node_ids_per_case(:,:,:)

    ! Info related to cut cells on this triangulation (this is computed at runtime)
    integer(ip),   allocatable :: mc_case_per_cell(:)       
    integer(ip),   allocatable :: mc_ptr_to_intersections(:) 
    type(point_t), allocatable :: mc_intersection_points(:)  

  contains

    ! Public TBP 
    generic                    :: create                        => serial_unfitted_triangulation_create
    procedure                  :: free                          => serial_unfitted_triangulation_free
    procedure, non_overridable :: create_unfitted_cell_iterator => serial_unfitted_triangulation_create_unfitted_cell_iterator
    procedure, non_overridable :: print_to_vtk_file             => serial_unfitted_triangulation_print_to_vtk_file
    
    ! Private TBP
    procedure,                  private :: serial_triangulation_create    => serial_unfitted_triangulation_serial_triangulation_create
    procedure,                  private :: serial_unfitted_triangulation_create
    procedure, non_overridable, private :: fulfills_assumptions           => serial_unfitted_triangulation_fulfills_assumptions
    procedure, non_overridable, private :: mc_tables_create               => serial_unfitted_triangulation_mc_tables_create
    procedure, non_overridable, private :: mc_tables_free                 => serial_unfitted_triangulation_mc_tables_free
    procedure, non_overridable, private :: mc_runtime_info_create         => serial_unfitted_triangulation_mc_runtime_info_create
    procedure, non_overridable, private :: mc_runtime_info_free           => serial_unfitted_triangulation_mc_runtime_info_free

  end type serial_unfitted_triangulation_t

  ! Derived types
  public :: unfitted_cell_accessor_t
  public :: unfitted_cell_iterator_t
  public :: serial_unfitted_triangulation_t

contains

#include "sbm_unfitted_cell_accessor.i90"
#include "sbm_unfitted_cell_iterator.i90"
#include "sbm_serial_unfitted_triangulation.i90"

end module serial_unfitted_triangulation_names
  
