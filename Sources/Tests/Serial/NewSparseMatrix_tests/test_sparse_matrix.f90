program test_coo_append

USE types_names
USE memor_names
USE serial_names
USE sparse_matrix_names
USE csr_sparse_matrix_names


implicit none

# include "debug.i90"

    type(sparse_matrix_t)       :: sparse_matrix
    type(csr_sparse_matrix_t)   :: csr_matrix
    type(serial_scalar_array_t) :: x
    type(serial_scalar_array_t) :: y

    call meminit()

!------------------------------------------------------------------
! NUMERIC
!------------------------------------------------------------------
    ! Create: START=>CREATE
    call sparse_matrix%create(num_rows=5,num_cols=5)
    ! Append: CREATE=>BUILD_NUMERIC
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(nz=10,                                 &
                              ia=(/1,2,3,4,5,1,2,3,4,5/),            &
                              ja=(/1,2,3,4,5,5,4,3,2,1/),            &
                              val=(/1.,2.,3.,4.,5.,5.,4.,3.,2.,1./))
    call sparse_matrix%insert(ia=1, ja=1, val=1.)
    call sparse_matrix%print( 6)
    ! Convert: BUILD_NUMERIC=>ASSEMBLED
    call sparse_matrix%convert('CSR')
    call sparse_matrix%print( 6)
    ! Update: ASSEMBLED=>UPDATE
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(nz=10,                                 &
                              ia=(/1,2,3,4,5,1,2,3,4,5/),            &
                              ja=(/1,2,3,4,5,5,4,3,2,1/),            &
                              val=(/1.,2.,3.,4.,5.,5.,4.,3.,2.,1./), &
                              imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%print( 6)
    ! Update: UPDATE=>ASSEMBLED
    call sparse_matrix%convert(mold=csr_matrix)
    call x%create_and_allocate(sparse_matrix%get_num_rows())
    ! Apply
    call x%init(1.0_rp)
    call y%create_and_allocate(sparse_matrix%get_num_cols())
    call sparse_matrix%apply(x,y)
    call x%print(6)
    call y%print(6)
    ! Free: ASSEMBLED=>ASSEMBLED_SYMBOLIC
    call sparse_matrix%free_in_stages(free_numerical_setup)
    ! Update: ASSEMBLED_SYMBOLIC=>UPDATE
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(nz=10,                                 &
                              ia=(/1,2,3,4,5,1,2,3,4,5/),            &
                              ja=(/1,2,3,4,5,5,4,3,2,1/),            &
                              val=(/1.,2.,3.,4.,5.,5.,4.,3.,2.,1./), &
                              imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    ! Free: UPDATE=>ASSEMBLED_SYMBOLIC
    call sparse_matrix%free_in_stages(free_numerical_setup)
    ! Free: ASSEMBLED_SYMBOLIC=>CREATED
    call sparse_matrix%free_in_stages(free_symbolic_setup)
    ! Free: CREATED=>START
    call sparse_matrix%free_in_stages(free_clean)

!------------------------------------------------------------------
! SYMBOLIC
!------------------------------------------------------------------

    ! Create: START=>CREATE
    call sparse_matrix%create(num_rows=5,num_cols=5)
    ! Append: CREATE=>BUILD_SYMBOLIC
    call sparse_matrix%insert(ia=1, ja=1, imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(nz=10,                                 &
                              ia=(/1,2,3,4,5,1,2,3,4,5/),            &
                              ja=(/1,2,3,4,5,5,4,3,2,1/))
    call sparse_matrix%insert(ia=1, ja=1)
    call sparse_matrix%print( 6)
    ! Convert: BUILD_SYMBOLIC=>ASSEMBLED_SYMBOLIC
    call sparse_matrix%convert(mold=csr_matrix)
    call sparse_matrix%print( 6)
    ! Update: ASSEMBLED_SYMBOLIC=>UPDATE
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(nz=10,                                 &
                              ia=(/1,2,3,4,5,1,2,3,4,5/),            &
                              ja=(/1,2,3,4,5,5,4,3,2,1/),            &
                              val=(/1.,2.,3.,4.,5.,5.,4.,3.,2.,1./), &
                              imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%insert(ia=1, ja=1, val=1., imin=1, imax=5, jmin=1, jmax=5 )
    call sparse_matrix%print( 6)
    ! Update: UPDATE=>ASSEMBLED
    call sparse_matrix%convert(mold=csr_matrix)
    ! Free: ASSEMBLED=>ASSEMBLED_SYMBOLIC
    call sparse_matrix%free_in_stages(free_numerical_setup)
    ! Free: ASSEMBLED_SYMBOLIC=>CREATED
    call sparse_matrix%free_in_stages(free_symbolic_setup)
    ! Free: CREATED=>START
    call sparse_matrix%free_in_stages(free_clean)

    call x%free()
    call y%free()

    call memstatus()

end program
