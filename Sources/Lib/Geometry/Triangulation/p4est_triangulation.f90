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
module p4est_triangulation_names
  use, intrinsic :: iso_c_binding
  
  use types_names
  use list_types_names
  use stdio_names
  use memor_names
  use environment_names
  use environment_parameters_names
  use execution_context_names
  use mpi_context_names
  use serial_context_names
  use uniform_hex_mesh_generator_names
  use uniform_hex_mesh_generator_parameters_names
  use p4est_bindings_names
  use reference_fe_names
  use triangulation_names
  use triangulation_parameters_names
  use std_vector_integer_ip_names
  use std_vector_integer_igp_names
  use std_vector_logical_names
  use function_names
  use field_names
  use cell_import_names
  use std_vector_point_names
  use FPL
  use hash_table_names
  use allocatable_array_names
  use fe_space_names
  use p4est_triangulation_parameters_names 
#ifdef MPI_MOD
  use mpi
#endif
  implicit none
#ifdef MPI_H
  include 'mpif.h'
#endif
# include "debug.i90"
  private
  
  type, extends(cell_iterator_t) :: p4est_cell_iterator_t
    private
    integer(ip) :: num_dims                  = 0
    integer(ip) :: num_vefs                  = 0
    integer(ip) :: base_pos_in_lst_vefs_gids = 0
    integer(ip) :: num_nodes                 = 0
    integer(ip) :: base_pos_in_nodal_coords  = 0
    integer(ip) :: num_local_cells           = 0
    type(p4est_base_triangulation_t), pointer :: p4est_triangulation => NULL()
  contains
    procedure                            :: create                  => p4est_cell_iterator_create
    procedure                            :: free                    => p4est_cell_iterator_free
    procedure                            :: first                   => p4est_cell_iterator_first
    procedure                            :: next                    => p4est_cell_iterator_next
    procedure                            :: set_gid                 => p4est_cell_iterator_set_gid
    procedure                            :: get_reference_fe        => p4est_cell_iterator_get_reference_fe
    procedure                            :: get_reference_fe_id     => p4est_cell_iterator_get_reference_fe_id
    procedure                            :: get_set_id              => p4est_cell_iterator_get_set_id
    procedure                            :: get_disconnected_set_id => p4est_cell_iterator_get_disconnected_set_id
    procedure                            :: set_set_id              => p4est_cell_iterator_set_set_id
    procedure                            :: get_level               => p4est_cell_iterator_get_level
    procedure                            :: get_num_vefs            => p4est_cell_iterator_get_num_vefs
    procedure                            :: get_num_vertices        => p4est_cell_iterator_get_num_vertices
    procedure                            :: get_num_nodes           => p4est_cell_iterator_get_num_nodes
    procedure, private                   :: get_vertex_coordinates  => p4est_cell_iterator_get_vertex_coordinates
    procedure                            :: get_nodes_coordinates   => p4est_cell_iterator_get_nodes_coordinates
    procedure                            :: get_ggid                => p4est_cell_iterator_get_ggid
    procedure                            :: get_my_part             => p4est_cell_iterator_get_mypart
    procedure                            :: get_vef_gid             => p4est_cell_iterator_get_vef_gid
    procedure                            :: get_vefs_gid            => p4est_cell_iterator_get_vefs_gid
    procedure                            :: get_vef_ggid            => p4est_cell_iterator_get_vef_ggid
    procedure                            :: get_vef_lid_from_gid    => p4est_cell_iterator_get_vef_lid_from_gid
    procedure                            :: get_vef_lid_from_ggid   => p4est_cell_iterator_get_vef_lid_from_ggid
    procedure                            :: get_vef                 => p4est_cell_iterator_get_vef
    procedure                            :: is_local                => p4est_cell_iterator_is_local
    procedure                            :: is_ghost                => p4est_cell_iterator_is_ghost
    procedure                            :: is_equal                => p4est_cell_iterator_is_equal
    procedure                            :: is_ancestor             => p4est_cell_iterator_is_ancestor
    procedure                            :: set_for_coarsening      => p4est_cell_iterator_set_for_coarsening
    procedure                            :: set_for_refinement      => p4est_cell_iterator_set_for_refinement
    procedure                            :: set_for_do_nothing      => p4est_cell_iterator_set_for_do_nothing
    procedure                            :: set_weight              => p4est_cell_iterator_set_weight
    procedure                            :: get_transformation_flag => p4est_cell_iterator_get_transformation_flag
    procedure                            :: get_permutation_index   => p4est_cell_iterator_get_permutation_index
    
    procedure                            :: get_num_subcells            => p4est_cell_iterator_get_num_subcells
    procedure                            :: get_num_subcell_nodes       => p4est_cell_iterator_get_num_subcell_nodes
    procedure                            :: get_phys_coords_of_subcell  => p4est_cell_iterator_get_phys_coords_of_subcell
    procedure                            :: get_ref_coords_of_subcell   => p4est_cell_iterator_get_ref_coords_of_subcell
    procedure                            :: get_num_subfacets           => p4est_cell_iterator_get_num_subfacets
    procedure                            :: get_num_subfacet_nodes      => p4est_cell_iterator_get_num_subfacet_nodes
    procedure                            :: get_phys_coords_of_subfacet => p4est_cell_iterator_get_phys_coords_of_subfacet
    procedure                            :: get_ref_coords_of_subfacet  => p4est_cell_iterator_get_ref_coords_of_subfacet
    procedure                            :: is_cut                      => p4est_cell_iterator_is_cut
    procedure                            :: is_interior                 => p4est_cell_iterator_is_interior
    procedure                            :: is_exterior                 => p4est_cell_iterator_is_exterior
    procedure                            :: is_interior_subcell         => p4est_cell_iterator_is_interior_subcell
    procedure                            :: is_exterior_subcell         => p4est_cell_iterator_is_exterior_subcell
  end type p4est_cell_iterator_t
  
  type, extends(vef_iterator_t) :: p4est_vef_iterator_t
    private
    type(p4est_base_triangulation_t), pointer :: p4est_triangulation => NULL()
  contains
     procedure                           :: create                    => p4est_vef_iterator_create
     procedure                           :: free                      => p4est_vef_iterator_free
     final                               ::                              p4est_vef_iterator_free_final
     procedure                           :: next                      => p4est_vef_iterator_next
     procedure                           :: has_finished              => p4est_vef_iterator_has_finished
     procedure                           :: get_num_nodes             => p4est_vef_iterator_get_num_nodes
     procedure                           :: get_nodes_coordinates     => p4est_vef_iterator_get_nodes_coordinates
     procedure                           :: get_ggid                  => p4est_vef_iterator_get_ggid
     procedure                           :: set_set_id                => p4est_vef_iterator_set_set_id
     procedure                           :: get_set_id                => p4est_vef_iterator_get_set_id
     procedure                           :: get_dim                   => p4est_vef_iterator_get_dim
     procedure                           :: is_at_boundary            => p4est_vef_iterator_is_at_boundary
     procedure                           :: is_at_interior            => p4est_vef_iterator_is_at_interior
     procedure                           :: is_local                  => p4est_vef_iterator_is_local
     procedure                           :: is_ghost                  => p4est_vef_iterator_is_ghost
     procedure                           :: is_at_interface           => p4est_vef_iterator_is_at_interface
     procedure                           :: is_proper                       => p4est_vef_iterator_is_proper
     procedure                           :: is_within_valid_range           => p4est_vef_iterator_is_within_valid_range
     procedure                           :: is_cut                          => p4est_vef_iterator_is_cut
     
     procedure                           :: get_num_cells_around            => p4est_vef_iterator_get_num_cells_around
     procedure                           :: get_cell_around                 => p4est_vef_iterator_get_cell_around
     
     ! Improper VEFs-only TBPs
     procedure                           :: get_num_improper_cells_around   => p4est_vef_iterator_get_num_improper_cells_around
     procedure                           :: get_improper_cell_around        => p4est_vef_iterator_get_improper_cell_around
     procedure                           :: get_improper_cell_around_ivef   => p4est_vef_iterator_get_improper_cell_around_ivef
     procedure                           :: get_improper_cell_around_subvef => p4est_vef_iterator_get_improper_cell_around_subvef
     procedure                           :: get_num_half_cells_around       => p4est_vef_iterator_get_num_half_cells_around
     procedure                           :: get_half_cell_around            => p4est_vef_iterator_get_half_cell_around
  end type p4est_vef_iterator_t
     
  type, extends(triangulation_t) ::  p4est_base_triangulation_t
    private
    integer(ip) :: k_2_1_balance            = -1
    integer(ip) :: k_ghost_cells            = -1
    integer(ip) :: p4est_log_level          = -1
    
    integer(ip) :: num_proper_vefs          = -1 
    integer(ip) :: num_improper_vefs        = -1 
 
    integer(ip) :: previous_num_local_cells = -1
    integer(ip) :: previous_num_ghost_cells = -1
    
    logical     :: clear_refinement_and_coarsening_flags_pending = .false.
    
    type(hex_lagrangian_reference_fe_t) :: reference_fe_geo
    type(hex_lagrangian_reference_fe_t) :: reference_fe_geo_linear
    real(rp)                            :: bounding_box_limits(1:SPACE_DIM,2)
    type(std_vector_point_t)            :: cell_wise_nodal_coordinates
    
    ! p4est-related data
    type(c_ptr) :: p4est_connectivity = c_null_ptr
    type(c_ptr) :: p4est              = c_null_ptr
    type(c_ptr) :: p4est_mesh         = c_null_ptr
    type(c_ptr) :: QHE                = c_null_ptr
    type(c_ptr) :: p4est_ghost        = c_null_ptr
    
    ! p4est quadrant connectivity (1:NUM_FACES_2D/3D,1:nQuads) => neighbor quadrant
    integer(P4EST_F90_LOCIDX),pointer      :: quad_to_quad(:,:)         => NULL()
    ! p4est face connectivity (1:NUM_FACES_2D/3D,1:nQuads) => neighbor faceId + orientation + non-conform info
    integer(P4EST_F90_QLEVEL),pointer      :: quad_to_face(:,:)         => NULL()   
    ! p4est face connectivity for mortars NUM_SUBFACES_FACE_2D/3D,1:nHalfFaces)
    integer(P4EST_F90_LOCIDX),pointer      :: quad_to_half(:,:)         => NULL()
    integer(P4EST_F90_LOCIDX),pointer      :: quad_to_corner(:,:)       => NULL()
    ! p4est edge connectivity for mortars NUM_SUBEDGES_EDGE_3D,1:nHalfEdges)
    integer(P4EST_F90_LOCIDX),pointer      :: quad_to_half_by_edge(:,:) => NULL()

    integer(P4EST_F90_LOCIDX), allocatable :: quad_to_quad_by_edge(:,:)
    integer(P4EST_F90_QLEVEL), allocatable :: quad_to_edge(:,:)

    ! TODO: The following 2x member variables should be replaced by our F200X implementation of "std::vector<T>" 
    ! p4est Integer coordinates of first quadrant node (xy/xyz,nQuads)
    integer(P4EST_F90_LOCIDX), allocatable :: quad_coords(:,:)
    ! p4est Integer Level of quadrant
    integer(P4EST_F90_QLEVEL), allocatable :: quad_level(:)
    
    integer(P4EST_F90_GLOIDX), allocatable :: global_first_quadrant(:)
    
    type(std_vector_integer_ip_t)          :: lst_vefs_gids
    type(std_vector_integer_ip_t)          :: ptr_cells_around_proper_vefs
    type(std_vector_integer_ip_t)          :: lst_cells_around_proper_vefs
    type(std_vector_integer_ip_t)          :: ptr_cells_around_improper_vefs
    type(std_vector_integer_ip_t)          :: lst_cells_around_improper_vefs
    type(std_vector_integer_ip_t)          :: ptr_improper_cells_around
    type(std_vector_integer_ip_t)          :: lst_improper_cells_around
    type(std_vector_integer_ip_t)          :: improper_vefs_improper_cell_around_ivef
    type(std_vector_integer_ip_t)          :: improper_vefs_improper_cell_around_subvef
    type(std_vector_integer_ip_t)          :: proper_vefs_dim
    type(std_vector_integer_ip_t)          :: improper_vefs_dim
    type(std_vector_logical_t)             :: proper_vefs_at_boundary
    type(std_vector_logical_t)             :: proper_vefs_at_interface
    type(std_vector_logical_t)             :: improper_vefs_at_interface
    type(std_vector_logical_t)             :: proper_vefs_is_ghost
    type(std_vector_logical_t)             :: improper_vefs_is_ghost
    type(std_vector_integer_ip_t)          :: refinement_and_coarsening_flags
    type(std_vector_integer_ip_t)          :: cell_weights
    type(std_vector_integer_ip_t)          :: cell_set_ids
    type(std_vector_integer_ip_t)          :: disconnected_cells_set_ids
    type(std_vector_integer_ip_t)          :: proper_vefs_set_ids
    type(std_vector_integer_ip_t)          :: improper_vefs_set_ids
    type(std_vector_integer_ip_t)          :: cell_myparts
    type(std_vector_integer_igp_t)         :: cell_ggids
    
     ! Scratch data required to optimize p4est_vef_iterator_get_nodes_coordinates
     integer(ip), allocatable              :: ptr_dofs_n_face(:)
     integer(ip), allocatable              :: lst_dofs_n_face(:)

     ! Auxiliar workspace required to compute the nodal coordinates
     type(hex_lagrangian_reference_fe_t)               :: nodal_coordinates_ref_fe
     type(p_reference_fe_t),              allocatable  :: nodal_coordinates_reference_fes(:)
     class(serial_fe_space_t),            allocatable  :: nodal_coordinates_fe_space
     type(fe_function_t)                               :: nodal_coordinates_fe_function
     integer(ip)                                       :: geometry_interpolation_order
     class(vector_function_t),            pointer      :: analytical_geom_mapping
     logical                                           :: geom_mapping_passed
  contains
    procedure                                   :: process_parameters                            =>  p4est_base_triangulation_process_parameters
  
    procedure                                   :: is_conforming                                 =>  p4est_base_triangulation_is_conforming
    procedure                                   :: set_analytical_geom_mapping                   =>  p4est_base_triangulation_set_analytical_geom_mapping
    
    ! Getters
    procedure                                   :: get_num_reference_fes                         => p4est_base_triangulation_get_num_reference_fes
    procedure                                   :: get_reference_fe                              => p4est_base_triangulation_get_reference_fe
    procedure                                   :: get_max_num_shape_functions                   => p4est_base_triangulation_get_max_num_shape_functions
    procedure                                   :: get_num_proper_vefs                           => p4est_base_triangulation_get_num_proper_vefs
    procedure                                   :: get_num_improper_vefs                         => p4est_base_triangulation_get_num_improper_vefs
    procedure                                   :: get_refinement_and_coarsening_flags           => p4est_bt_get_refinement_and_coarsening_flags
    
    ! Set up related methods
    procedure                 , non_overridable  :: refine_and_coarsen                                   => p4est_base_triangulation_refine_and_coarsen
    procedure, private        , non_overridable  :: update_p4est_mesh                                    => p4est_base_triangulation_update_p4est_mesh
    procedure, private        , non_overridable  :: update_topology_from_p4est_mesh                      => p4est_base_triangulation_update_topology_from_p4est_mesh
    procedure, private        , non_overridable  :: extend_p4est_topology_arrays_to_ghost_cells          => p4est_bt_extend_p4est_topology_arrays_to_ghost_cells
    procedure, private        , non_overridable  :: find_missing_corner_neighbours                       => p4est_bt_find_missing_corner_neighbours
    procedure, private        , non_overridable  :: get_ptr_vefs_x_cell                                  => p4est_base_triangulation_get_ptr_vefs_x_cell
    procedure, private        , non_overridable  :: update_lst_vefs_gids_and_cells_around                => p4est_bt_update_lst_vefs_gids_and_cells_around
    procedure, private        , non_overridable  :: update_cell_ggids                                    => p4est_base_triangulation_update_cell_ggids
    procedure, private        , non_overridable  :: update_cell_myparts                                  => p4est_base_triangulation_update_cell_myparts
    procedure, private        , non_overridable  :: update_cell_set_ids                                  => p4est_bt_update_cell_set_ids
    procedure, private        , non_overridable  :: update_cell_weights                                  => p4est_bt_update_cell_weights
    procedure, private        , non_overridable  :: comm_cell_set_ids                                    => p4est_bt_comm_cell_set_ids
    procedure, private        , non_overridable  :: comm_cell_wise_vef_set_ids                           => p4est_bt_comm_cell_wise_vef_set_ids
    procedure, private        , non_overridable  :: update_vef_set_ids                                   => p4est_bt_update_vef_set_ids
    procedure, private        , non_overridable  :: extract_local_cell_wise_vef_set_ids                  => p4est_bt_extract_local_cell_wise_vef_set_ids
    procedure, private        , non_overridable  :: fill_ghost_cells_from_cell_wise_vef_set_ids          => p4est_bt_fill_ghost_cells_from_cell_wise_vef_set_ids
    procedure, private        , non_overridable  :: fill_local_cells_from_cell_wise_vef_set_ids          => p4est_bt_fill_local_cells_from_cell_wise_vef_set_ids
    procedure, private        , non_overridable  :: allocate_and_fill_cell_wise_nodal_coords_pre_mapping => p4est_bt_allocate_and_fill_cell_wise_nodal_coords_pre_mapping
    procedure, private        , non_overridable  :: clear_refinement_and_coarsening_flags                => p4est_bt_clear_refinement_and_coarsening_flags
    procedure                 , non_overridable  :: clear_cell_weights                                   => p4est_bt_clear_cell_weights
    procedure                 , non_overridable  :: clear_cell_set_ids                                   => p4est_bt_clear_cell_set_ids
    procedure                                    :: fill_cells_set                                       => p4est_bt_fill_cells_set
    procedure                                    :: compute_max_cells_set_id                             => p4est_bt_compute_max_cells_set_id
    procedure                                    :: resize_disconnected_cells_set                        => p4est_bt_resize_disconnected_cells_set
    procedure                                    :: fill_disconnected_cells_set                          => p4est_bt_fill_disconnected_cells_set
    procedure, private        , non_overridable  :: initialize_vef_set_ids                               => p4est_bt_initialize_vef_set_ids
    procedure, private        , non_overridable  :: clear_vef_set_ids                                    => p4est_bt_clear_vef_set_ids
    procedure, private        , non_overridable  :: update_cell_import                                   => p4est_bt_update_cell_import
    procedure                                    :: get_previous_num_local_cells                         => p4est_bt_get_previous_num_local_cells 
    procedure                                    :: get_previous_num_ghost_cells                         => p4est_bt_get_previous_num_ghost_cells
    
    procedure, private                           :: allocate_and_gen_reference_fe_geo_scratch_data       => p4est_bt_allocate_and_gen_reference_fe_geo_scratch_data
    procedure, private                           :: free_reference_fe_geo_scratch_data                   => p4est_bt_free_reference_fe_geo_scratch_data

    ! Nodal coordinates
    procedure                 , non_overridable :: setup_nodal_coordinates_fe_space                 => p4est_bt_setup_nodal_coordinates_fe_space
    procedure                 , non_overridable :: setup_nodal_coordinates_fe_function              => p4est_bt_setup_nodal_coordinates_fe_function
    procedure                 , non_overridable :: nodal_coordinates_fe_function_to_cell_wise_array => p4est_bt_nodal_coordinates_fe_function_to_cell_wise_array
    procedure, private        , non_overridable :: free_workspace_to_compute_nodal_coordinates      => p4est_bt_free_workspace_to_compute_nodal_coordinates

    ! Cell traversals-related TBPs
    procedure                                   :: create_cell_iterator                  => p4est_create_cell_iterator
    procedure                                   :: free_cell_iterator                    => p4est_free_cell_iterator
    
    ! VEF traversals-related TBPs
    procedure                                   :: create_vef_iterator                   => p4est_create_vef_iterator
    procedure                                   :: free_vef_iterator                     => p4est_free_vef_iterator
    
    ! Methods to perform nearest neighbor exchange
    procedure                                   :: get_migration_num_snd                 => p4est_bt_get_migration_num_snd
    procedure                                   :: get_migration_lst_snd                 => p4est_bt_get_migration_lst_snd
    procedure                                   :: get_migration_snd_ptrs                => p4est_bt_get_migration_snd_ptrs
    procedure                                   :: get_migration_pack_idx                => p4est_bt_get_migration_pack_idx
    procedure                                   :: get_migration_num_rcv                 => p4est_bt_get_migration_num_rcv
    procedure                                   :: get_migration_lst_rcv                 => p4est_bt_get_migration_lst_rcv
    procedure                                   :: get_migration_rcv_ptrs                => p4est_bt_get_migration_rcv_ptrs
    procedure                                   :: get_migration_unpack_idx              => p4est_bt_get_migration_unpack_idx
    procedure                                   :: get_migration_new2old                 => p4est_bt_get_migration_new2old
    procedure                                   :: get_migration_old2new                 => p4est_bt_get_migration_old2new    

#ifndef ENABLE_P4EST
    procedure, non_overridable :: not_enabled_error => p4est_base_triangulation_not_enabled_error
#endif
  end type p4est_base_triangulation_t
  
  public :: p4est_base_triangulation_t, p4est_cell_iterator_t, p4est_vef_iterator_t
  
  type, extends(p4est_base_triangulation_t) ::  p4est_serial_triangulation_t
    private
  contains
    procedure, private                          :: p4est_serial_triangulation_create
    generic                                     :: create                                        => p4est_serial_triangulation_create
    procedure                                   :: free                                          => p4est_serial_triangulation_free    
  end type p4est_serial_triangulation_t
  
  public :: p4est_serial_triangulation_t
  
  type, extends(p4est_base_triangulation_t) ::  p4est_par_triangulation_t
    private
    ! Scratch data required for migration. Should it be packed in a data type ???
    ! EXPORT SIDE
    integer(P4EST_F90_LOCIDX) :: num_snd
    type(c_ptr) :: p_lst_snd  = c_null_ptr
    type(c_ptr) :: p_snd_ptrs = c_null_ptr
    type(c_ptr) :: p_pack_idx = c_null_ptr
    integer(P4EST_F90_LOCIDX), pointer :: lst_snd(:)
    integer(P4EST_F90_LOCIDX), pointer :: snd_ptrs(:)
    integer(P4EST_F90_LOCIDX), pointer :: pack_idx(:)
    
    ! IMPORT SIDE
    integer(P4EST_F90_LOCIDX) :: num_rcv
    type(c_ptr) :: p_lst_rcv    = c_null_ptr
    type(c_ptr) :: p_rcv_ptrs   = c_null_ptr
    type(c_ptr) :: p_unpack_idx = c_null_ptr
    integer(P4EST_F90_LOCIDX), pointer :: lst_rcv(:)
    integer(P4EST_F90_LOCIDX), pointer :: rcv_ptrs(:)
    integer(P4EST_F90_LOCIDX), pointer :: unpack_idx(:)
    
    type(std_vector_integer_ip_t) :: old_vef_set_ids
    type(std_vector_integer_ip_t) :: new_vef_set_ids
    
    type(c_ptr) :: p_old2new = c_null_ptr
    type(c_ptr) :: p_new2old = c_null_ptr
    integer(P4EST_F90_LOCIDX), pointer :: old2new(:)
    integer(P4EST_F90_LOCIDX), pointer :: new2old(:)
  contains
    procedure, private                          :: p4est_par_triangulation_create
    generic                                     :: create                                           => p4est_par_triangulation_create
    procedure, private, non_overridable         :: environment_aggregate_tasks                      => p4est_triangulation_environment_aggregate_tasks
    procedure                                   :: free                                             => p4est_par_triangulation_free 
    procedure                                   :: clear_disconnected_cells_set_ids                 => p4est_par_triangulation_clear_disconnected_cells_set_ids
    procedure                                   :: redistribute                                     => p4est_par_triangulation_redistribute
    procedure                                   :: update_migration_control_data                    => p4est_par_triangulation_update_migration_control_data
    procedure                                   :: migrate_cell_set_ids                             => p4est_par_triangulation_migrate_cell_set_ids
    procedure                                   :: migrate_cell_weights                             => p4est_par_triangulation_migrate_cell_weights
    procedure                                   :: migrate_vef_set_ids                              => p4est_par_triangulation_migrate_vef_set_ids
    procedure                                   :: get_migration_num_snd                            => p4est_par_triangulation_get_migration_num_snd
    procedure                                   :: get_migration_lst_snd                            => p4est_par_triangulation_get_migration_lst_snd
    procedure                                   :: get_migration_snd_ptrs                           => p4est_par_triangulation_get_migration_snd_ptrs
    procedure                                   :: get_migration_pack_idx                           => p4est_par_triangulation_get_migration_pack_idx
    procedure                                   :: get_migration_num_rcv                            => p4est_par_triangulation_get_migration_num_rcv
    procedure                                   :: get_migration_lst_rcv                            => p4est_par_triangulation_get_migration_lst_rcv
    procedure                                   :: get_migration_rcv_ptrs                           => p4est_par_triangulation_get_migration_rcv_ptrs
    procedure                                   :: get_migration_unpack_idx                         => p4est_par_triangulation_get_migration_unpack_idx
    procedure                                   :: get_migration_new2old                            => p4est_par_triangulation_get_migration_new2old
    procedure                                   :: get_migration_old2new                            => p4est_par_triangulation_get_migration_old2new
  end type p4est_par_triangulation_t
  
  public :: p4est_par_triangulation_t
contains

! The value of this CPP macro should be zero 
! whenever the code below is extended to support forests of
! octrees with more than a single octree. By now, it just
! supports a single octree, and thus the sort of optimizations
! that are enabled through the CPP macro can be activated.
#define ENABLE_SINGLE_OCTREE_OPTS 1

#include "sbm_p4est_base_triangulation.i90"
#include "sbm_p4est_cell_iterator.i90"
#include "sbm_p4est_vef_iterator.i90"
#include "sbm_p4est_serial_triangulation.i90"
#include "sbm_p4est_par_triangulation.i90"

end module p4est_triangulation_names
