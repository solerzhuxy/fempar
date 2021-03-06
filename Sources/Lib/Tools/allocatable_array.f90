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
!***********************************************************************
! All allocatable routines
!***********************************************************************
# define var_attr allocatable, target
# define point(a,b) call move_alloc(a,b)
# define generic_status_test             allocated
# define generic_memalloc_interface      memalloc
# define generic_memrealloc_interface    memrealloc
# define generic_memfree_interface       memfree
# define generic_memmovealloc_interface  memmovealloc
!***********************************************************************

!=============================================================================
! module allocatable_array_ip1_names
!=============================================================================

module allocatable_array_ip1_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_ip1_t
     !private alert.SB : It should be private
     integer(ip)               :: nd1
     integer(ip), allocatable  :: a(:)
   contains
     procedure, non_overridable :: create         => allocatable_array_ip1_create
     procedure, non_overridable :: free           => allocatable_array_ip1_free
     procedure, non_overridable :: assign         => allocatable_array_ip1_assign
     generic  :: assignment(=) => assign
  end type allocatable_array_ip1_t

  public :: allocatable_array_ip1_t
# define var_type type(allocatable_array_ip1_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_ip1_create(this, nd1) 
    implicit none
    class(allocatable_array_ip1_t), intent(inout) :: this
    integer(ip)                   , intent(in)    :: nd1
    call this%free()
    this%nd1 = nd1
    call memalloc(nd1,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_ip1_create

  subroutine allocatable_array_ip1_free(this) 
    implicit none
    class(allocatable_array_ip1_t), intent(inout) :: this
    this%nd1 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_ip1_free
  
  subroutine allocatable_array_ip1_assign(this,array_in)
    implicit none
    class(allocatable_array_ip1_t), intent(inout) :: this
    type(allocatable_array_ip1_t) , intent(in)    :: array_in
    call this%free()
    call this%create(array_in%nd1)
    this%a = array_in%a
  end subroutine allocatable_array_ip1_assign
  
# include "mem_body.i90"

end module allocatable_array_ip1_names

!=============================================================================
! module allocatable_array_ip2_names
!=============================================================================

module allocatable_array_ip2_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_ip2_t
     integer(ip)               :: nd1=0, nd2=0
     integer(ip), allocatable  :: a(:,:)
   contains
     procedure :: create => allocatable_array_ip2_create
     procedure :: free   => allocatable_array_ip2_free
     procedure :: resize => allocatable_array_ip2_resize
  end type allocatable_array_ip2_t
  public :: allocatable_array_ip2_t
# define var_type type(allocatable_array_ip2_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_ip2_create(this, nd1, nd2) 
    implicit none
    class(allocatable_array_ip2_t), intent(inout) :: this
    integer(ip)                   , intent(in)  :: nd1, nd2
    call this%free()
    this%nd1 = nd1
    this%nd2 = nd2
    call memalloc(nd1,nd2,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_ip2_create

  subroutine allocatable_array_ip2_free(this) 
    implicit none
    class(allocatable_array_ip2_t), intent(inout) :: this
    this%nd1 = 0
    this%nd2 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_ip2_free
  
  subroutine allocatable_array_ip2_resize(this, nd1, nd2) 
    implicit none
    class(allocatable_array_ip2_t), intent(inout) :: this
    integer(ip)                   , intent(in)  :: nd1, nd2
    
    if ( .not. allocated(this%a) ) then
      call this%create(nd1, nd2)
    else if ( this%nd1 < nd1 .or. this%nd2 < nd2 ) then
      call memrealloc(nd1,nd2,this%a,__FILE__,__LINE__)
    end if 
    this%nd1 = nd1
    this%nd2 = nd2
  end subroutine allocatable_array_ip2_resize
  
# include "mem_body.i90"

end module allocatable_array_ip2_names

!=============================================================================
! module allocatable_array_igp1_names
!=============================================================================

module allocatable_array_igp1_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_igp1_t
     !private alert.SB : It should be private
     integer(ip)                :: nd1
     integer(igp), allocatable  :: a(:)
   contains
     procedure :: create => allocatable_array_igp1_create
     procedure :: free   => allocatable_array_igp1_free
  end type allocatable_array_igp1_t

  public :: allocatable_array_igp1_t
# define var_type type(allocatable_array_igp1_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_igp1_create(this, nd1) 
    implicit none
    integer(ip)    , intent(in)  :: nd1
    class(allocatable_array_igp1_t), intent(inout) :: this
    call this%free()
    this%nd1 = nd1
    call memalloc(nd1,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_igp1_create

  subroutine allocatable_array_igp1_free(this) 
    implicit none
    class(allocatable_array_igp1_t), intent(inout) :: this
    this%nd1 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_igp1_free

# include "mem_body.i90"

end module allocatable_array_igp1_names

!=============================================================================
! module allocatable_array_igp2_names
!=============================================================================

module allocatable_array_igp2_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_igp2_t
     !private alert.SB : It should be private
     integer(ip)               :: nd1=0, nd2=0
     integer(igp), allocatable :: a(:,:)
   contains
     procedure :: create => allocatable_array_igp2_create
     procedure :: free   => allocatable_array_igp2_free
     procedure :: resize => allocatable_array_igp2_resize
  end type allocatable_array_igp2_t
  public :: allocatable_array_igp2_t
# define var_type type(allocatable_array_igp2_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_igp2_create(this, nd1, nd2) 
    implicit none
    class(allocatable_array_igp2_t), intent(inout) :: this
    integer(ip)                   , intent(in)  :: nd1, nd2
    call this%free()
    this%nd1 = nd1
    this%nd2 = nd2
    call memalloc(nd1,nd2,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_igp2_create

  subroutine allocatable_array_igp2_free(this) 
    implicit none
    class(allocatable_array_igp2_t), intent(inout) :: this
    this%nd1 = 0
    this%nd2 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_igp2_free
  
  subroutine allocatable_array_igp2_resize(this, nd1, nd2) 
    implicit none
    class(allocatable_array_igp2_t), intent(inout) :: this
    integer(ip)                   , intent(in)  :: nd1, nd2
    
    if ( .not. allocated(this%a) ) then
      call this%create(nd1, nd2)
    else if ( this%nd1 < nd1 .or. this%nd2 < nd2 ) then
      call memrealloc(nd1,nd2,this%a,__FILE__,__LINE__)
    end if 
    this%nd1 = nd1
    this%nd2 = nd2
  end subroutine allocatable_array_igp2_resize
  
# include "mem_body.i90"

end module allocatable_array_igp2_names

!=============================================================================
! module allocatable_array_rp1_names
!=============================================================================

module allocatable_array_rp1_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_rp1_t
     integer(ip)               :: nd1
     real(rp)    , allocatable :: a(:)
   contains
     procedure, non_overridable :: create         => allocatable_array_rp1_create
     procedure, non_overridable :: resize         => allocatable_array_rp1_resize
     procedure, non_overridable :: free           => allocatable_array_rp1_free
     procedure, non_overridable :: move_alloc_out => allocatable_array_rp1_move_alloc_out
     procedure, non_overridable :: move_alloc_in  => allocatable_array_rp1_move_alloc_in
     procedure, non_overridable :: get_array      => allocatable_array_rp1_get_array
     procedure, non_overridable :: assign         => allocatable_array_rp1_assign
     generic  :: assignment(=) => assign
  end type allocatable_array_rp1_t
  
  public :: allocatable_array_rp1_t
# define var_type type(allocatable_array_rp1_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_rp1_create(this, nd1) 
    implicit none
    class(allocatable_array_rp1_t), intent(inout) :: this
    integer(ip)                   , intent(in)    :: nd1
    call this%free()
    this%nd1 = nd1
    call memalloc(nd1,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp1_create
   
  subroutine allocatable_array_rp1_resize(this, nd1) 
    implicit none
    integer(ip)    , intent(in)  :: nd1
    class(allocatable_array_rp1_t), intent(inout) :: this
    if ( this%nd1 < nd1 ) then
       this%nd1 = nd1
       call memrealloc(nd1,this%a,__FILE__,__LINE__)
    end if
  end subroutine allocatable_array_rp1_resize

  subroutine allocatable_array_rp1_free(this) 
    implicit none
    class(allocatable_array_rp1_t), intent(inout) :: this
    this%nd1 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp1_free
  
  subroutine allocatable_array_rp1_move_alloc_out(this, a)
    implicit none
    class(allocatable_array_rp1_t), intent(inout) :: this
    real(rp), allocatable      , intent(inout) :: a(:)
    assert (.not. allocated (a))
    !assert (allocated(this%a))
    call move_alloc(from=this%a, to=a) 
  end subroutine allocatable_array_rp1_move_alloc_out
  
  subroutine allocatable_array_rp1_move_alloc_in(this, a)
    implicit none
    class(allocatable_array_rp1_t), intent(inout) :: this
    real(rp), allocatable      , intent(inout) :: a(:)
    !assert (allocated (a))
    assert (.not. allocated(this%a))
    call move_alloc(to=this%a, from=a) 
    this%nd1 = size(this%a)
  end subroutine allocatable_array_rp1_move_alloc_in
  
  function allocatable_array_rp1_get_array(this)
    implicit none
    class(allocatable_array_rp1_t), target , intent(in) :: this
    real(rp), pointer :: allocatable_array_rp1_get_array(:)
    allocatable_array_rp1_get_array => this%a
  end function allocatable_array_rp1_get_array
  
  subroutine allocatable_array_rp1_assign(this,array_in)
    implicit none
    class(allocatable_array_rp1_t), intent(inout) :: this
    type(allocatable_array_rp1_t) , intent(in)    :: array_in
    call this%free()
    call this%create(array_in%nd1)
    this%a = array_in%a
  end subroutine allocatable_array_rp1_assign
  

# include "mem_body.i90"

end module allocatable_array_rp1_names

!=============================================================================
! module allocatable_array_rp2_names
!=============================================================================

module allocatable_array_rp2_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_rp2_t
     integer(ip)               :: nd1, nd2
     real(rp)    , allocatable :: a(:,:) ! Simple real 2D array
   contains
     procedure :: create => allocatable_array_rp2_create
     procedure :: resize => allocatable_array_rp2_resize
     procedure :: free   => allocatable_array_rp2_free
  end type allocatable_array_rp2_t
  public :: allocatable_array_rp2_t
# define var_type type(allocatable_array_rp2_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_rp2_create(this, nd1, nd2) 
    implicit none
    integer(ip)    , intent(in)  :: nd1, nd2
    class(allocatable_array_rp2_t), intent(inout) :: this
    call this%free()
    this%nd1 = nd1
    this%nd2 = nd2
    call memalloc(nd1,nd2,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp2_create

  subroutine allocatable_array_rp2_resize(this, nd1, nd2) 
    implicit none
    integer(ip)    , intent(in)  :: nd1, nd2
    class(allocatable_array_rp2_t), intent(inout) :: this
    if ( this%nd1 < nd1 .or. this%nd2 < nd2 ) then
       this%nd1 = nd1
       this%nd2 = nd2
       call memrealloc(nd1,nd2,this%a,__FILE__,__LINE__)
    end if
  end subroutine allocatable_array_rp2_resize

  subroutine allocatable_array_rp2_free(this) 
    implicit none
    class(allocatable_array_rp2_t), intent(inout) :: this
    this%nd1 = 0
    this%nd2 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp2_free

# include "mem_body.i90"

end module allocatable_array_rp2_names

!=============================================================================
! module allocatable_array_rp3_names
!=============================================================================

module allocatable_array_rp3_names
  use types_names
  use memor_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  type allocatable_array_rp3_t
     integer(ip)               :: nd1, nd2,nd3
     real(rp)    , allocatable :: a(:,:,:) ! Simple real 2D array
   contains
     procedure :: create => allocatable_array_rp3_create
     procedure :: free   => allocatable_array_rp3_free
  end type allocatable_array_rp3_t
  public :: allocatable_array_rp3_t
# define var_type type(allocatable_array_rp3_t)
# define var_size 52
# define bound_kind ip
# include "mem_header.i90"
  public :: memalloc,  memrealloc,  memfree, memmovealloc

contains

  subroutine allocatable_array_rp3_create(this, nd1, nd2, nd3) 
    implicit none
    class(allocatable_array_rp3_t), intent(inout) :: this
    integer(ip)    , intent(in)  :: nd1, nd2, nd3
    call this%free()
    this%nd1 = nd1
    this%nd2 = nd2
    this%nd3 = nd3
    call memalloc(nd1,nd2,nd3,this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp3_create

  subroutine allocatable_array_rp3_free(this) 
    implicit none
    class(allocatable_array_rp3_t), intent(inout) :: this
    this%nd1 = 0
    this%nd2 = 0
    this%nd3 = 0
    if ( allocated(this%a) ) call memfree(this%a,__FILE__,__LINE__)
  end subroutine allocatable_array_rp3_free

# include "mem_body.i90"

end module allocatable_array_rp3_names

!=============================================================================
! module allocatable_array_names
!=============================================================================

module allocatable_array_names
  use types_names
  use memor_names
  use allocatable_array_ip1_names
  use allocatable_array_ip2_names
  use allocatable_array_igp1_names
  use allocatable_array_igp2_names
  use allocatable_array_rp1_names
  use allocatable_array_rp2_names
  use allocatable_array_rp3_names
#ifdef memcheck
  use iso_c_binding
#endif
  implicit none
# include "debug.i90"
  private

  ! Types
  public :: allocatable_array_ip1_t, allocatable_array_ip2_t, &
       &    allocatable_array_igp1_t, allocatable_array_igp2_t, & 
       &    allocatable_array_rp1_t, allocatable_array_rp2_t, allocatable_array_rp3_t

  ! Functions
  public :: memalloc, memrealloc, memfree, memmovealloc

end module allocatable_array_names

