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

module base_output_handler_names

USE FPL
USE types_names
USE memor_names
USE fe_space_names,              only: serial_fe_space_t, fe_iterator_t, fe_accessor_t
USE fe_function_names,           only: fe_function_t
USE output_handler_fe_field_names
USE output_handler_patch_names
USE output_handler_cell_fe_function_names
USE output_handler_fe_iterator_names

implicit none
#include "debug.i90"
private

    integer(ip), parameter :: cell_node_field_array_size = 10

    integer(ip), parameter :: BASE_OUTPUT_HANDLER_STATE_INIT   = 0
    integer(ip), parameter :: BASE_OUTPUT_HANDLER_STATE_OPEN   = 1
    integer(ip), parameter :: BASE_OUTPUT_HANDLER_STATE_FILL   = 2

    !-----------------------------------------------------------------
    ! State transition diagram for type(base_output_handler_t)
    !-----------------------------------------------------------------
    ! Note: it is desirable that the state management occurs only
    !       inside this class to get a cleaner implementation
    !       of the son classes
    !-----------------------------------------------------------------
    ! Note: 
    !       * All setters must be called before OPEN
    !       * All getters (except get_fe_space) must be called
    !         after OPEN
    !       * FILLED occurs when metadata is filled from ohcff.
    !-----------------------------------------------------------------
    ! Input State         | Action                | Output State 
    !-----------------------------------------------------------------
    ! Init                | free                  | Init
    ! Init                | Open                  | Open
    !-----------------------------------------------------------------
    ! Open                | free                  | Init
    ! Open                | fill_data             | Fill
    ! Open                | close                 | Init
    !-----------------------------------------------------------------
    ! Fill                | free                  | Init
    ! Fill                | close                 | Init

    type, abstract :: base_output_handler_t
    private
        class(serial_fe_space_t),            pointer    :: fe_space => NULL()
        class(output_handler_fe_iterator_t), pointer    :: iterator => NULL()
        type(output_handler_cell_fe_function_t)         :: ohcff
        type(output_handler_fe_iterator_t)              :: default_iterator
        type(output_handler_fe_field_t),    allocatable :: fe_fields(:)
        type(output_handler_cell_vector_t), allocatable :: cell_vectors(:)
        integer(ip)                                     :: state                 = BASE_OUTPUT_HANDLER_STATE_INIT
        integer(ip)                                     :: number_fields         = 0
        integer(ip)                                     :: number_cell_vectors   = 0
    contains
    private
        procedure, non_overridable, public :: free                         => base_output_handler_free
        procedure, non_overridable, public :: get_number_nodes             => base_output_handler_get_number_nodes
        procedure, non_overridable, public :: get_number_cells             => base_output_handler_get_number_cells
        procedure, non_overridable, public :: has_mixed_cell_topologies    => base_output_handler_has_mixed_cell_topologies
        procedure, non_overridable, public :: get_number_dimensions        => base_output_handler_get_number_dimensions
        procedure, non_overridable, public :: get_number_fields            => base_output_handler_get_number_fields
        procedure, non_overridable, public :: get_number_cell_vectors      => base_output_handler_get_number_cell_vectors
        procedure, non_overridable, public :: get_fe_field                 => base_output_handler_get_fe_field
        procedure, non_overridable, public :: get_cell_vector              => base_output_handler_get_cell_vector
        procedure, non_overridable, public :: get_fe_space                 => base_output_handler_get_fe_space
        procedure, non_overridable, public :: set_iterator                 => base_output_handler_set_iterator
        procedure, non_overridable         :: resize_fe_fields_if_needed   => base_output_handler_resize_fe_fields_if_needed
        procedure, non_overridable         :: resize_cell_vectors_if_needed=> base_output_handler_resize_cell_vectors_if_needed
        procedure, non_overridable, public :: attach_fe_space              => base_output_handler_attach_fe_space
        procedure, non_overridable, public :: add_fe_function              => base_output_handler_add_fe_function
        procedure, non_overridable, public :: add_cell_vector              => base_output_handler_add_cell_vector
        procedure, non_overridable, public :: fill_data                    => base_output_handler_fill_data
        procedure, non_overridable, public :: open                         => base_output_handler_open
        procedure, non_overridable, public :: close                        => base_output_handler_close
        procedure(base_output_handler_open_body),                      public, deferred :: open_body
        procedure(base_output_handler_append_time_step),               public, deferred :: append_time_step
        procedure(base_output_handler_allocate_cell_and_nodal_arrays),         deferred :: allocate_cell_and_nodal_arrays
        procedure(base_output_handler_append_cell),                            deferred :: append_cell
        procedure(base_output_handler_write),                          public, deferred :: write
        procedure(base_output_handler_close_body),                     public, deferred :: close_body
        procedure(base_output_handler_free_body),                              deferred :: free_body
    end type

    abstract interface
        subroutine base_output_handler_open_body(this, dir_path, prefix, parameter_list)
            import base_output_handler_t
            import ParameterList_t
            class(base_output_handler_t),    intent(inout) :: this
            character(len=*),                intent(in)    :: dir_path
            character(len=*),                intent(in)    :: prefix
            type(ParameterList_t), optional, intent(in)    :: parameter_list
        end subroutine

        subroutine base_output_handler_append_time_step(this, value)
            import base_output_handler_t
            import rp
            class(base_output_handler_t), intent(inout) :: this
            real(rp),                     intent(in)    :: value
        end subroutine

        subroutine base_output_handler_write(this)
            import base_output_handler_t
            class(base_output_handler_t), intent(inout) :: this
        end subroutine

        subroutine base_output_handler_allocate_cell_and_nodal_arrays(this)
            import base_output_handler_t
            class(base_output_handler_t), intent(inout) :: this
        end subroutine

        subroutine base_output_handler_append_cell(this, subcell_accessor)
            import base_output_handler_t
            import patch_subcell_accessor_t
            class(base_output_handler_t),   intent(inout) :: this
            type(patch_subcell_accessor_t), intent(in)    :: subcell_accessor
        end subroutine

        subroutine base_output_handler_close_body(this)
            import base_output_handler_t
            class(base_output_handler_t), intent(inout) :: this
        end subroutine

        subroutine base_output_handler_free_body(this)
            import base_output_handler_t
            class(base_output_handler_t), intent(inout) :: this
        end subroutine
    end interface

public :: base_output_handler_t

contains

!---------------------------------------------------------------------
!< base_output_handler_T PROCEDURES
!---------------------------------------------------------------------

    subroutine base_output_handler_free(this)
    !-----------------------------------------------------------------
    !< Free base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(inout) :: this
        integer(ip)                                 :: i
    !-----------------------------------------------------------------
        call this%free_body()
        if(allocated(this%fe_fields)) then
            do i=1, size(this%fe_fields)
                call this%fe_fields(i)%free()
            enddo
            deallocate(this%fe_fields)
        endif
        nullify(this%iterator)
        call this%ohcff%free()
        call this%default_iterator%free()
        nullify(this%fe_space)
        this%number_cell_vectors   = 0
        this%number_fields         = 0
        this%state                 = BASE_OUTPUT_HANDLER_STATE_INIT
    end subroutine base_output_handler_free

    subroutine base_output_handler_set_iterator(this, iterator)
    !-----------------------------------------------------------------
    !< Set output handler fe_iterator
    !-----------------------------------------------------------------
        class(base_output_handler_t),                intent(inout) :: this
        class(output_handler_fe_iterator_t), target, intent(in)  :: iterator
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        this%iterator => iterator
    end subroutine base_output_handler_set_iterator


    function base_output_handler_get_number_nodes(this) result(number_nodes)
    !-----------------------------------------------------------------
    !< Return the number of nodes
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        integer(ip)                              :: number_nodes
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        number_nodes = this%ohcff%get_number_nodes()
    end function base_output_handler_get_number_nodes


    function base_output_handler_get_number_cells(this) result(number_cells)
    !-----------------------------------------------------------------
    !< Return the number of cells
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        integer(ip)                              :: number_cells
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        number_cells = this%ohcff%get_number_cells()
    end function base_output_handler_get_number_cells


    function base_output_handler_get_number_dimensions(this) result(number_dimensions)
    !-----------------------------------------------------------------
    !< Return the number of dimensions
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        integer(ip)                              :: number_dimensions
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        number_dimensions = this%ohcff%get_number_dimensions()
    end function base_output_handler_get_number_dimensions




    function base_output_handler_has_mixed_cell_topologies(this) result(mixed_cell_topologies)
    !-----------------------------------------------------------------
    !< Return if the mesh has mixed cell topologies
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        logical                                  :: mixed_cell_topologies
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        mixed_cell_topologies = this%ohcff%has_mixed_cell_topologies()
    end function base_output_handler_has_mixed_cell_topologies


    function base_output_handler_get_number_fields(this) result(number_fields)
    !-----------------------------------------------------------------
    !< Return the number of fields
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        integer(ip)                              :: number_fields
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_OPEN .or. this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        number_fields = this%number_fields
    end function base_output_handler_get_number_fields


    function base_output_handler_get_number_cell_vectors(this) result(number_cell_vectors)
    !-----------------------------------------------------------------
    !< Return the number of cell_vectors
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        integer(ip)                              :: number_cell_vectors
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_OPEN .or. this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        number_cell_vectors = this%number_cell_vectors
    end function base_output_handler_get_number_cell_vectors


    function base_output_handler_get_fe_field(this, field_id) result(field)
    !-----------------------------------------------------------------
    !< Return a fe field given its id
    !-----------------------------------------------------------------
        class(base_output_handler_t),    target, intent(in) :: this
        integer(ip),                             intent(in) :: field_id
        type(output_handler_fe_field_t), pointer            :: field
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        assert(field_id <= this%number_fields)
        field => this%fe_fields(field_id)
    end function base_output_handler_get_fe_field


    function base_output_handler_get_cell_vector(this, cell_vector_id) result(cell_vector)
    !-----------------------------------------------------------------
    !< Return a cell vector given its id
    !-----------------------------------------------------------------
        class(base_output_handler_t),       target, intent(in) :: this
        integer(ip),                                intent(in) :: cell_vector_id
        type(output_handler_cell_vector_t), pointer            :: cell_vector
    !-----------------------------------------------------------------
        assert(cell_vector_id <= this%number_cell_vectors)
        cell_vector => this%cell_vectors(cell_vector_id)
    end function base_output_handler_get_cell_vector


    subroutine base_output_handler_attach_fe_space(this, fe_space)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t),          intent(inout) :: this
        class(serial_fe_space_t), target,      intent(in)    :: fe_space
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        this%fe_space => fe_space
    end subroutine base_output_handler_attach_fe_space


    function base_output_handler_get_fe_space(this) result(fe_space)
    !-----------------------------------------------------------------
    !< Return a fe_space pointer
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(in) :: this
        class(serial_fe_space_t), pointer        :: fe_space
    !-----------------------------------------------------------------
        fe_space => this%fe_space
    end function base_output_handler_get_fe_space


    subroutine base_output_handler_resize_fe_fields_if_needed(this, number_fields)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t),       intent(inout) :: this
        integer(ip),                        intent(in)    :: number_fields
        integer(ip)                                       :: current_size
        type(output_handler_fe_field_t), allocatable      :: temp_fe_functions(:)
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        if(.not. allocated(this%fe_fields)) then
            allocate(this%fe_fields(cell_node_field_array_size))
        elseif(number_fields > size(this%fe_fields)) then
            current_size = size(this%fe_fields)
            call move_alloc(from=this%fe_fields, to=temp_fe_functions)
            allocate(this%fe_fields(int(1.5*current_size)))
            this%fe_fields(1:current_size) = temp_fe_functions(1:current_size)
            deallocate(temp_fe_functions)
        endif
    end subroutine base_output_handler_resize_fe_fields_if_needed


    subroutine base_output_handler_resize_cell_vectors_if_needed(this, number_fields)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t),       intent(inout) :: this
        integer(ip),                        intent(in)    :: number_fields
        integer(ip)                                       :: current_size
        type(output_handler_cell_vector_t), allocatable   :: temp_cell_vectors(:)
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        if(.not. allocated(this%cell_vectors)) then
            allocate(this%cell_vectors(cell_node_field_array_size))
        elseif(number_fields > size(this%cell_vectors)) then
            current_size = size(this%cell_vectors)
            call move_alloc(from=this%cell_vectors, to=temp_cell_vectors)
            allocate(this%cell_vectors(int(1.5*current_size)))
            this%cell_vectors(1:current_size) = temp_cell_vectors(1:current_size)
            deallocate(temp_cell_vectors)
        endif
    end subroutine base_output_handler_resize_cell_vectors_if_needed


    subroutine base_output_handler_add_fe_function(this, fe_function, field_id, name, diff_operator)
    !-----------------------------------------------------------------
    !< Add a fe_function to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t),       intent(inout) :: this
        type(fe_function_t),                intent(in)    :: fe_function
        integer(ip),                        intent(in)    :: field_id
        character(len=*),                   intent(in)    :: name
        character(len=*), optional,         intent(in)    :: diff_operator
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        call this%resize_fe_fields_if_needed(this%number_fields+1)
        this%number_fields = this%number_fields + 1
        call this%fe_fields(this%number_fields)%set(fe_function, field_id, name, diff_operator)
    end subroutine base_output_handler_add_fe_function


    subroutine base_output_handler_add_cell_vector(this, cell_vector, name)
    !-----------------------------------------------------------------
    !< Add a fe_function to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t),       intent(inout) :: this
        real(rp), allocatable,              intent(in)    :: cell_vector(:)
        character(len=*),                   intent(in)    :: name
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        call this%resize_cell_vectors_if_needed(this%number_cell_vectors+1)
        this%number_cell_vectors = this%number_cell_vectors + 1
        call this%cell_vectors(this%number_cell_vectors)%set(cell_vector, name)
    end subroutine base_output_handler_add_cell_Vector


    subroutine base_output_handler_open(this, dir_path, prefix, parameter_list)
    !-----------------------------------------------------------------
    !< Open procedure. State diagram transition management
    !-----------------------------------------------------------------
        class(base_output_handler_t),    intent(inout) :: this
        character(len=*),                intent(in)    :: dir_path
        character(len=*),                intent(in)    :: prefix
        type(ParameterList_t), optional, intent(in)    :: parameter_list
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_INIT)
        call this%open_body(dir_path, prefix, parameter_list)
        this%state = BASE_OUTPUT_HANDLER_STATE_OPEN
    end subroutine base_output_handler_open


    subroutine base_output_handler_close(this)
    !-----------------------------------------------------------------
    !< Close procedure. State diagram transition management
    !-----------------------------------------------------------------
        class(base_output_handler_t), intent(inout) :: this
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_OPEN .or. this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        call this%close_body()
        this%state = BASE_OUTPUT_HANDLER_STATE_INIT
    end subroutine base_output_handler_close


    subroutine base_output_handler_fill_data(this, update_mesh)
    !-----------------------------------------------------------------
    !< Attach a fe_space to the base_output_handler_t derived type
    !-----------------------------------------------------------------
        class(base_output_handler_t), target, intent(inout) :: this
        logical,                              intent(in)    :: update_mesh
        type(fe_accessor_t)                                 :: fe
        type(output_handler_patch_t)                        :: patch
        type(patch_subcell_iterator_t)                      :: subcell_iterator
    !-----------------------------------------------------------------
        assert(this%state == BASE_OUTPUT_HANDLER_STATE_OPEN .or. this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        assert(associated(this%fe_space))

        ! Ouput_handler_FE_iterator 
        if(.not. associated (this%iterator)) then
            this%iterator => this%default_iterator
            call this%iterator%create(this%fe_space)
        endif

        if(update_mesh) then
            ! Create Output Cell Handler and allocate patch fields
            call this%ohcff%create(this%fe_space, this%iterator, this%number_fields, this%fe_fields(1:this%number_fields))
            this%state = BASE_OUTPUT_HANDLER_STATE_FILL

            ! Allocate geometry and connectivity arrays
            call this%allocate_cell_and_nodal_arrays()
        endif

        assert(this%state == BASE_OUTPUT_HANDLER_STATE_FILL)
        call patch%create(this%number_fields, this%number_cell_vectors)
        ! Translate coordinates and connectivities to VTK format for every subcell
        call this%iterator%init()
        do while ( .not. this%iterator%has_finished())
            ! Get Finite element
            call this%iterator%current(fe)
            if ( fe%is_local() ) then
                call this%ohcff%fill_patch(fe, &
                                           this%number_fields, &
                                           this%fe_fields(1:this%number_fields), &
                                           this%number_cell_vectors, &
                                           this%cell_vectors(1:this%number_cell_vectors), &
                                           patch)
                subcell_iterator = patch%get_subcells_iterator()
!               ! Fill data
                do while(.not. subcell_iterator%has_finished())
                    call this%append_cell(subcell_iterator%get_accessor())
                    call subcell_iterator%next()
                enddo
            endif
            call this%iterator%next()
        end do

        call patch%free()
        call fe%free()

    end subroutine base_output_handler_fill_data

end module base_output_handler_names

