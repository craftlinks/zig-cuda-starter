// Import the standard library
const std = @import("std");
// Target NVIDIA GPU architecture (Turing)
const gpu_arch = "sm_75";

pub fn build(b: *std.Build) void {
    // Set up standard build options (target platform and optimization level)
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a shared library (.dll/.so) named "starter"
    const lib = b.addSharedLibrary(.{
        .name = "starter",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add executable target
    const exe = b.addExecutable(.{
        .name = "cuda_example",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.pie = true;  // Enable Position Independent Executable
    exe.linkLibC();  // Add libc linking for the executable


    // Compile CUDA source and get the object file path
    const cuda_obj = compileCuda(b);
    
    // Get CUDA installation path from environment variable, default to /usr/local/cuda
    const cuda_path = "/usr/local/cuda/";


    // Add CUDA dependencies to executable
    exe.addObjectFile(.{ .cwd_relative = cuda_obj });
    exe.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{cuda_path}) });
    exe.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/lib64", .{cuda_path}) });
    exe.linkSystemLibrary("cuda");
    exe.linkSystemLibrary("cudart");
    
    
    lib.addObjectFile(.{ .cwd_relative = cuda_obj });

    // Add CUDA include and library paths
    lib.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{cuda_path}) });
    lib.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/lib64", .{cuda_path}) });
    // Link against CUDA runtime libraries
    lib.linkSystemLibrary("cuda");
    lib.linkSystemLibrary("cudart");
    lib.linkLibC();

    // Set up installation step to put the library in the current directory
    const lib_install = b.addInstallArtifact(lib, .{
        .dest_dir = .{ .override = .{ .custom = "." } },
    });
    const exe_install = b.addInstallArtifact(exe, .{});

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(&exe_install.step);
    const run_step = b.step("run", "Run the example program");
    run_step.dependOn(&run_cmd.step);

    // Add test step
    const main_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addObjectFile(.{ .cwd_relative = cuda_obj });
    main_tests.addIncludePath(.{ .cwd_relative = b.fmt("{s}/include", .{cuda_path}) });
    main_tests.addLibraryPath(.{ .cwd_relative = b.fmt("{s}/lib64", .{cuda_path}) });
    main_tests.linkSystemLibrary("cuda");
    main_tests.linkSystemLibrary("cudart");
    main_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    const run_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_tests.step);

    b.getInstallStep().dependOn(&lib_install.step);
    b.getInstallStep().dependOn(&exe_install.step);
}

/// Compiles the CUDA source file using nvcc compiler
fn compileCuda(b: *std.Build) []const u8 {
    // Define source and target paths for CUDA compilation
    const source_path = b.pathJoin(&.{ "src", "cuda", "add.cu" });
    const target_path = b.pathJoin(&.{ "src", "cuda", "cuda.o" });

    // Set up nvcc compiler arguments
    const nvcc_args = &.{
        "nvcc",
        "-c",                  // Compile to object file
        source_path,
        "-o",
        target_path,
        "-O3",                 // Maximum optimization
        b.fmt("--gpu-architecture={s}", .{gpu_arch}),  // Set target GPU architecture
        "--compiler-options",
        "-fPIC",              // Position Independent Code for shared library
    };

    // Run nvcc compiler as a child process
    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = nvcc_args,
    }) catch @panic("Failed to compile CUDA code");

    // Check for compilation errors
    if (result.stderr.len != 0) {
        std.log.err("NVCC Error: {s}", .{result.stderr});
        @panic("Failed to compile CUDA code");
    }

    return target_path;
}
