program test_direct_solver

USE types_names
USE memor_names
USE fempar_names
USE sparse_matrix_names
USE direct_solver_names
USE direct_solver_parameters_names
USE direct_solver_creational_methods_dictionary_names
USE FPL
USE IR_Precision
use iso_c_binding


implicit none

# include "debug.i90"

    type(sparse_matrix_t)          :: sparse_matrix
    type(direct_solver_t)          :: direct_solver
    type(ParameterList_t)          :: parameter_list
    type(ParameterList_t), pointer :: direct_solver_params
    type(serial_scalar_array_t)    :: x
    type(serial_scalar_array_t)    :: y
    integer(ip)                    :: nrhs = 3
    real(rp), allocatable          :: xx(:,:)
    real(rp), allocatable          :: yy(:,:)
    integer                        :: FPLError
    real(c_double)                 :: control_params(20) = 0
    integer                        :: iparm(64) = 0
    integer                        :: i, iters=5

    call meminit()
    ! ParameterList: initialize
    call FPL_Init()
    call the_direct_solver_creational_methods_dictionary%Init()
    call parameter_list%Init()

    ! Sparse matrix: create
    call sparse_matrix%create(4, .false., .true., SPARSE_MATRIX_SIGN_UNKNOWN )
    call sparse_matrix%insert(nz=8,                    &
                              ia=(/1,1,2,3,3,4,4,4/),  &
                              ja=(/1,4,2,3,4,1,3,4/),  &
                              val=(/1.,2.,3.,5.,6.,2.,6.,8./))
    call sparse_matrix%convert('CSR')
    call sparse_matrix%print(6)

    ! Serial scalar array: create and initialize
    call x%create_and_allocate(sparse_matrix%get_num_rows())
    call x%init(1.0_rp)
    call y%create_and_allocate(sparse_matrix%get_num_cols())
    call x%print(6)
    call memalloc(sparse_matrix%get_num_rows(), nrhs, xx, __FILE__, __LINE__)
    xx = 1.0_rp
    call memalloc(sparse_matrix%get_num_cols(), nrhs, yy, __FILE__, __LINE__)


    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! PARDISO MKL
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    direct_solver_params => parameter_list%NewSubList(Key=pardiso_mkl)

    ! ParameterList: set parameters
    FPLError = 0
    FPLError = FPLError + direct_solver_params%set(key = direct_solver_type,        value = pardiso_mkl)
    FPLError = FPLError + direct_solver_params%set(key = pardiso_mkl_matrix_type,   value = pardiso_mkl_uss)
    FPLError = FPLError + direct_solver_params%set(key = pardiso_mkl_message_level, value = 0)
    FPLError = FPLError + direct_solver_params%set(key = pardiso_mkl_iparm,         value = iparm)
    check(FPLError == 0)


    do i=1, iters

#ifdef ENABLE_MKL
        ! Direct solver: create and set properties
        if(i==1) then
            call direct_solver%set_type_from_pl(direct_solver_params)
            call direct_solver%set_matrix(sparse_matrix)
        else
            call direct_solver%set_parameters_from_pl(direct_solver_params)
        endif

        ! Direct solver: analisys, factorization and solve
        call direct_solver%solve(x,y)
        call direct_solver%log_info()
        call y%print(6)
        call direct_solver%solve(xx,yy)
        call direct_solver%log_info()
        print*, yy

        if(i/=iters) then
            print*, ''
            print*, '!< =============================================='
            print*, '!< UPDATE MATRIX WITH SAME_NONZERO_PATTERN:', mod(i,2)==0
            print*, '!< =============================================='
        endif

        call direct_solver%replace_matrix(sparse_matrix, same_nonzero_pattern=mod(i,2)==0)
#endif

    enddo

    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! UMFPACK
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    direct_solver_params => parameter_list%NewSubList(Key=UMFPACK)

    ! ParameterList: set parameters
    FPLError = 0
    FPLError = FPLError + direct_solver_params%set(key = DIRECT_SOLVER_TYPE,     value = UMFPACK)
    FPLError = FPLError + direct_solver_params%set(key = UMFPACK_CONTROL_PARAMS, value = control_params)
    check(FPLError == 0)

    do i=1, iters

#ifdef ENABLE_UMFPACK
        ! Direct solver: create and set properties
        if(i==1) then
            call direct_solver%set_type_from_pl(direct_solver_params)
            call direct_solver%set_matrix(sparse_matrix)
        else
            call direct_solver%set_parameters_from_pl(direct_solver_params)
        endif
    
        ! Direct solver: analisys, factorization and solve
        call direct_solver%solve(x,y)
        call direct_solver%log_info()
        call y%print(6)
        call direct_solver%solve(xx,yy)
        call direct_solver%log_info()
        print*, yy

        if(i/=iters) then
            print*, ''
            print*, '!< =============================================='
            print*, '!< UPDATE MATRIX WITH SAME_NONZERO_PATTERN:', mod(i,2)==0
            print*, '!< =============================================='
        endif

        call direct_solver%replace_matrix(sparse_matrix, same_nonzero_pattern=mod(i,2)==0)
#endif

    enddo

    ! Free
    call parameter_list%free()
    call direct_solver%free()
    call sparse_matrix%free()
    call x%free()
    call y%free()
    call memfree(xx, __FILE__, __LINE__)
    call memfree(yy, __FILE__, __LINE__)

    call memstatus()

end program test_direct_solver
