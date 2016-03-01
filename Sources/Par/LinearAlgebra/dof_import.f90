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
module dof_import_names
  use types_names
  use memor_names
  implicit none
  private

  ! Number of rows raw_interface_data(:,:)
  integer(ip), parameter :: num_rows_raw_interface_data = 4
  
  ! Row identifiers for accessing raw_interface_data(:,:)
  ! (generated from type(par_fe_space_t))
  integer(ip), parameter :: neighbour_part_id = 1
  integer(ip), parameter :: owner_flag        = 2 
  integer(ip), parameter :: max_egid          = 3
  integer(ip), parameter :: lpos_dof_max_egid = 4
  
  ! Possible values for owner_flag column
  integer(igp), parameter :: uncoupled  = -1
  integer(igp), parameter :: owner      = -2  
  integer(igp), parameter :: non_owner  = -3
  
  integer(ip), parameter :: estimation_nparts_around_part = 100
  
  ! Host for data needed to perform nearest neighbour communication
  type dof_import_t
     private
     integer(ip)       ::          &
        ipart,                     &    ! Part identifier
        nparts                          ! Number of parts
      
     integer :: num_rcv                 ! From how many neighbours does the part receive data ?
     integer, allocatable ::     &           
        list_rcv(:),             &      ! From which neighbours does the part receive data ?
        rcv_ptrs(:)                     ! How much data does the part receive from each neighbour ?
     integer(ip), allocatable :: &           
        unpack_idx(:)                   ! Where the data received from each neighbour is copied/added 
                                        ! on the local vectors of the part ?

     integer :: num_snd                 ! To how many neighbours does the part send data ? 
     integer, allocatable ::     &           
        list_snd(:),             &      ! To which neighbours does the part send data ?
        snd_ptrs(:)                     ! How much data does the part send to each neighbour?
     integer(ip), allocatable :: & 
        pack_idx(:)                     ! Where is located the data to be sent to 
                                        ! each neighbour on the local vectors of the part ?
  contains
    procedure, non_overridable :: create         => dof_import_create
    procedure, non_overridable :: free           => dof_import_free
    procedure, non_overridable :: print          => dof_import_print
    procedure, non_overridable :: get_num_rcv    => dof_import_get_num_rcv
    procedure, non_overridable :: get_list_rcv   => dof_import_get_list_rcv
    procedure, non_overridable :: get_rcv_ptrs   => dof_import_get_rcv_ptrs
    procedure, non_overridable :: get_unpack_idx => dof_import_get_unpack_idx
    procedure, non_overridable :: get_num_snd    => dof_import_get_num_snd
    procedure, non_overridable :: get_list_snd   => dof_import_get_list_snd
    procedure, non_overridable :: get_snd_ptrs   => dof_import_get_snd_ptrs
    procedure, non_overridable :: get_pack_idx   => dof_import_get_pack_idx    
  end type dof_import_t

  ! Types
  public :: dof_import_t

 
  public :: num_rows_raw_interface_data
  public :: neighbour_part_id, owner_flag, max_egid, lpos_dof_max_egid
  public :: uncoupled, owner, non_owner

contains
  !=============================================================================
  subroutine dof_import_create ( this, ipart, nparts, num_itfc_couplings, dofs_lid, raw_interface_data )
    implicit none
    class(dof_import_t), intent(inout)  :: this
    integer(ip)        , intent(in)     :: ipart
    integer(ip)        , intent(in)     :: nparts
    integer(ip)        , intent(in)     :: num_itfc_couplings
    integer(ip)        , intent(in)     :: dofs_lid(num_itfc_couplings)
    integer(igp)       , intent(in)     :: raw_interface_data(num_rows_raw_interface_data, num_itfc_couplings)
    
    integer(ip), allocatable :: parts_rcv_visited(:)
    integer(ip), allocatable :: parts_snd_visited(:)
    integer(ip)              :: col, part_id, i

    this%ipart  = ipart
    this%nparts = nparts
    
    call memalloc ( this%nparts, parts_rcv_visited, __FILE__, __LINE__ )
    parts_rcv_visited = 0
    call memalloc ( this%nparts, parts_snd_visited, __FILE__, __LINE__ )
    parts_snd_visited = 0
    call memalloc ( this%nparts, this%list_rcv, __FILE__, __LINE__ )
    call memalloc ( this%nparts, this%list_snd, __FILE__, __LINE__ )
    call memalloc ( this%nparts+1, this%snd_ptrs, __FILE__, __LINE__ )
    this%snd_ptrs = 0
    call memalloc ( this%nparts+1, this%rcv_ptrs, __FILE__, __LINE__ )
    this%rcv_ptrs = 0
    
    this%num_rcv = 0
    this%num_snd = 0
    do col=1, num_itfc_couplings
       part_id = raw_interface_data( neighbour_part_id, col)
       if ( raw_interface_data(owner_flag,col) == owner ) then
         if ( parts_rcv_visited(part_id) == 0 ) then
            this%num_rcv = this%num_rcv + 1
            parts_rcv_visited(part_id) = this%num_rcv
            this%list_rcv(this%num_rcv) = part_id
         end if
         this%rcv_ptrs(parts_rcv_visited(part_id)+1) = this%rcv_ptrs(parts_rcv_visited(part_id)+1) + 1 
       else if ( raw_interface_data(owner_flag,col) == non_owner ) then
         if ( parts_snd_visited(part_id) == 0 ) then
            this%num_snd = this%num_snd + 1
            parts_snd_visited(part_id) = this%num_snd
            this%list_snd(this%num_snd) = part_id
         end if
         this%snd_ptrs(parts_snd_visited(part_id)+1) = this%snd_ptrs(parts_snd_visited(part_id)+1) + 1        
       end if
    end do
    
    this%rcv_ptrs(1) = 1 
    do i=1, this%num_rcv
      this%rcv_ptrs(i+1) = this%rcv_ptrs(i+1) + this%rcv_ptrs(i)
    end do
    
    this%snd_ptrs(1) = 1 
    do i=1, this%num_snd
      this%snd_ptrs(i+1) = this%snd_ptrs(i+1) + this%snd_ptrs(i)
    end do
    
    call memrealloc ( this%num_snd+1, this%snd_ptrs, __FILE__, __LINE__ )
    call memrealloc ( this%num_rcv+1, this%rcv_ptrs, __FILE__, __LINE__ )
    call memrealloc ( this%num_snd, this%list_snd, __FILE__, __LINE__ )
    call memrealloc ( this%num_rcv, this%list_rcv, __FILE__, __LINE__ )    
    
    call memalloc ( this%snd_ptrs(this%num_snd+1)-1, this%pack_idx, __FILE__, __LINE__ )
    call memalloc ( this%rcv_ptrs(this%num_rcv+1)-1, this%unpack_idx, __FILE__, __LINE__ )
    
    do col=1, num_itfc_couplings
       part_id = raw_interface_data( neighbour_part_id, col)
       if ( raw_interface_data(owner_flag,col) == owner ) then
         this%unpack_idx(this%rcv_ptrs(parts_rcv_visited(part_id))) = dofs_lid(col)
         this%rcv_ptrs(parts_rcv_visited(part_id)) = this%rcv_ptrs(parts_rcv_visited(part_id)) + 1 
       else if ( raw_interface_data(owner_flag,col) == non_owner ) then
         this%pack_idx(this%snd_ptrs(parts_snd_visited(part_id))) = dofs_lid(col)
         this%snd_ptrs(parts_snd_visited(part_id)) = this%snd_ptrs(parts_snd_visited(part_id)) + 1        
       end if
    end do
    
    call memfree ( parts_rcv_visited, __FILE__, __LINE__ )
    call memfree ( parts_snd_visited, __FILE__, __LINE__ )
     
    do i=this%num_snd, 2, -1
      this%snd_ptrs(i) = this%snd_ptrs(i-1) 
    end do
    this%snd_ptrs(1) = 1 
    
    do i=this%num_rcv, 2, -1
      this%rcv_ptrs(i) = this%rcv_ptrs(i-1) 
    end do
    this%rcv_ptrs(1) = 1 
    
    call this%print(6)

    
  end subroutine dof_import_create

  !=============================================================================
  subroutine dof_import_free ( this )
    implicit none
    class(dof_import_t), intent(inout)  :: this
    this%ipart  = 0
    this%nparts = 0
    this%num_rcv = 0
    this%num_snd = 0
    if (allocated(this%list_rcv)) call memfree ( this%list_rcv,__FILE__,__LINE__)
    if (allocated(this%rcv_ptrs)) call memfree ( this%rcv_ptrs,__FILE__,__LINE__)
    if (allocated(this%unpack_idx)) call memfree ( this%unpack_idx,__FILE__,__LINE__)
    if (allocated(this%list_snd)) call memfree ( this%list_snd,__FILE__,__LINE__)
    if (allocated(this%snd_ptrs)) call memfree ( this%snd_ptrs,__FILE__,__LINE__)
    if (allocated(this%pack_idx)) call memfree ( this%pack_idx,__FILE__,__LINE__)
  end subroutine dof_import_free

  !=============================================================================
  subroutine dof_import_print (this, lu_out)
    implicit none
    class(dof_import_t)   , intent(in)  :: this
    integer(ip)          , intent(in)  :: lu_out

    if(lu_out>0) then
       write(lu_out,'(a)') '*** begin dof_import_t data structure ***'
       write(lu_out,'(a,i10)') 'Number of parts:', &
            &  this%nparts
       write(lu_out,'(a,i10)') 'Number of parts I have to receive from:', &
            &  this%num_rcv
       write(lu_out,'(a)') 'List of parts I have to receive from:'
       write(lu_out,'(10i10)') this%list_rcv(1:this%num_rcv)
       write(lu_out,'(a)') 'Rcv_ptrs:'
       write(lu_out,'(10i10)') this%rcv_ptrs(1:this%num_rcv+1)
       write(lu_out,'(a)') 'Unpack:'
       write(lu_out,'(10i10)') this%unpack_idx(1:this%rcv_ptrs(this%num_rcv+1)-1)

       write(lu_out,'(a,i10)') 'Number of parts I have send to:', &
            &  this%num_snd
       write(lu_out,'(a)') 'List of parts I have to send to:'
       write(lu_out,'(10i10)') this%list_snd(1:this%num_snd)
       write(lu_out,'(a)') 'Snd_ptrs::'
       write(lu_out,'(10i10)') this%snd_ptrs(1:this%num_snd+1)
       write(lu_out,'(a)') 'Pack:'
       write(lu_out,'(10i10)') this%pack_idx(1:this%snd_ptrs(this%num_snd+1)-1)
       write(lu_out,'(a)') '*** end dof_import_t data structure ***'
    end if
  end subroutine dof_import_print
  
  function dof_import_get_num_rcv(this) 
    implicit none
    class(dof_import_t), intent(in) :: this
    integer(ip)                     :: dof_import_get_num_rcv
    
    dof_import_get_num_rcv = this%num_rcv
  end function dof_import_get_num_rcv
  
  function dof_import_get_list_rcv(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_list_rcv(:)
    
    dof_import_get_list_rcv => this%list_rcv
  end function dof_import_get_list_rcv
  
  function dof_import_get_rcv_ptrs(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_rcv_ptrs(:)
    
    dof_import_get_rcv_ptrs => this%rcv_ptrs
  end function dof_import_get_rcv_ptrs
  
  function dof_import_get_unpack_idx(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_unpack_idx(:)
    
    dof_import_get_unpack_idx => this%unpack_idx
  end function dof_import_get_unpack_idx
  
  function dof_import_get_num_snd(this) 
    implicit none
    class(dof_import_t), intent(in) :: this
    integer(ip)                     :: dof_import_get_num_snd
    
    dof_import_get_num_snd = this%num_snd
  end function dof_import_get_num_snd
  
  function dof_import_get_list_snd(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_list_snd(:)
    
    dof_import_get_list_snd => this%list_snd
  end function dof_import_get_list_snd
  
  function dof_import_get_snd_ptrs(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_snd_ptrs(:)
    
    dof_import_get_snd_ptrs => this%snd_ptrs
  end function dof_import_get_snd_ptrs
  
  function dof_import_get_pack_idx(this) 
    implicit none
    class(dof_import_t), target, intent(in) :: this
    integer(ip)        , pointer            :: dof_import_get_pack_idx(:)
    
    dof_import_get_pack_idx => this%pack_idx
  end function dof_import_get_pack_idx
  

end module dof_import_names
