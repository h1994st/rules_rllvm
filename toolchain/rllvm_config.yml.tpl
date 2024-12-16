clang_filepath = '%{llvm_dist_path_prefix}bin/clang-orig'
clangxx_filepath = '%{llvm_dist_path_prefix}bin/clang++-orig'
llvm_ar_filepath = '%{llvm_dist_path_prefix}bin/llvm-ar'
llvm_config_filepath = '%{llvm_dist_path_prefix}bin/llvm-config'
llvm_link_filepath = '%{llvm_dist_path_prefix}bin/llvm-link'
llvm_objcopy_filepath = '%{llvm_dist_path_prefix}bin/llvm-objcopy'
is_configure_only = %{skip_bitcode_generation}
log_level = %{rllvm_log_level}
