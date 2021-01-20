// To make a windows executable run without spawning a command prompt, you
// need to run a custom linker command.  You do that by setting up a workspace
// and triggering the link on the .READY_FOR_CUSTOM_LINK_COMMAND message.
// The custom link proc is mostly copied from the compile_me.jai example in the
// Compiler module.

// The run_custom_link_command below differs from the one in the compile_me.jai
// file in the following ways (search for the @tag below):
//
// @WinApp Adds the necessary linker arguments to make it output a non-command line
//         oriented application.
//
// @Spam   The line which spews all the linker crap has been commented out.
//
// @Color  I added some ansi color escape sequences to the output.


set_options :: (using options: *Build_Options) {
    use_custom_link_command = true;
}


#run {
    filepath := "foo.jai";
    executable := "foo";

    output_path : string;

    build_options := get_build_options();
    build_options.output_type = .NO_OUTPUT;
    set_build_options(build_options);

    build_options.output_type = .EXECUTABLE;
    build_options.output_executable_name = executable;
    build_options.output_path = output_path;
    set_options(*build_options);
    workspace := compiler_create_workspace();
    set_build_options(build_options, workspace);

    compiler_begin_intercept(workspace);
    add_build_file(filepath, workspace);

    while true {
        message := compiler_wait_for_message();
        if !message continue;
        if message.workspace != workspace continue;
        if message.kind == .COMPLETE break;

        build_steps(message);
    }

    compiler_end_intercept(workspace);
}


build_steps :: (message : *Compiler_Message) {
    if message.kind == .COMPILATION_PHASE {
        phase_message := cast (*Compiler_Message_Compilation_Phase) message;
        if phase_message.phase.phase == .READY_FOR_CUSTOM_LINK_COMMAND
            run_custom_link_command(message.workspace, phase_message, use_system_linker_if_able=true);
    }
}


run_custom_link_command :: (w: Workspace, m: *Compiler_Message_Compilation_Phase, use_system_linker_if_able := true) {
    options := get_build_options(w);

    // Use the workspace's Os_Target since we want to support
    // cross-compilation at some point!
    target := options.os_target;
    target_windows := target == .WINDOWS;
    target_linux   := target == .LINUX;
    target_macosx  := target == .MACOS;

    use_lld := !((target == OS) && use_system_linker_if_able);

    #if OS == .WINDOWS {
        system_linker_exe_name := "link.exe";
    }

    #if OS == .LINUX || OS == .MACOS {
        system_linker_exe_name := "ld";
    }

    #if OS == .WINDOWS {
        if !use_lld && target_windows {
            // If we have opted to use the system linker and we're on Windows,
            // then attempt to find link.exe, otherwise fallback to LLD (or maybe error?)
            vc_path, linker_path := Windows_Resources.find_visual_studio_in_a_ridiculous_garbage_way();
            if linker_path {
                system_linker_exe_name = tprint("%\\%", linker_path, system_linker_exe_name);
            } else {
                compiler_report("Could not find link.exe path, falling back to using LLD", mode = .WARNING);
                use_lld = true;
            }
        }
    }

    suffix := "";
    #if OS == .WINDOWS {
        suffix = ".exe";
    }

    target_filename := tprint("%1%2%3", options.output_path, options.output_executable_name, suffix);

    exe_name := get_path_of_running_executable();
    index, found := last_index_of_string(exe_name, "jai/");

    lld_exe_name: string;
    if use_lld {
        compiler_base_path := "c:/jai/";  // Will be overridden by the below...
        if found {
            compiler_base_path = exe_name;
            compiler_base_path.count = index + 4;
        } else {
            print("Metaprogram is unable to find the path to the compiler, in order to run lld.\n");
        }

        #if OS == .WINDOWS {
            lld := "lld.exe";
        }

        #if OS == .MACOS {
            lld := "lld-macosx";
        }

        #if OS == .LINUX {
            lld := "lld-linux";
        }

        lld_exe_name = tprint("%1%2%3", compiler_base_path, "bin/", lld);
    }


    // Unfortunately, right now we are using CreateProcessW because that allows
    // one to be specific about security, etc (or if it isn't specific enough we can
    // change to CreateProcessExW). HOWEVER, it doesn't inherit the path so we need
    // to provide the path explicitly. That sucks. Maybe we have to change to system.
    // Or duplicate system's ability to use the path.

    arguments: [..] string;

    if use_lld {
        array_add(*arguments, lld_exe_name);
        array_add(*arguments, "-flavor");

        // choose the flavor based on the target OS.
        if      target_windows array_add(*arguments, "link");
        else if target_linux   array_add(*arguments, "Gnu");
        else if target_macosx  array_add(*arguments, "Darwin");
    } else {
        array_add(*arguments, system_linker_exe_name);
    }

    if target_windows array_add(*arguments, "/nologo");

    // Object files.
    for m.compiler_generated_object_files array_add(*arguments, it);
    for m.support_object_files array_add(*arguments, it);

    if target_windows {
        // Target filename.
        array_add(*arguments, tprint("/OUT:%", target_filename));

        array_add(*arguments, "/MACHINE:AMD64");
        array_add(*arguments, "/INCREMENTAL:NO");
        array_add(*arguments, "/DEBUG");
        //array_add(*arguments, "/OPT:REF");

        // @WinApp These arguments make the linker generate a Windows application, instead
        // of a command line program.
        array_add(*arguments, "/SUBSYSTEM:WINDOWS");
        array_add(*arguments, "/ENTRY:main");
        array_add(*arguments, "/IGNORE:4216");

        // If generating an executable, then create lib and exp file inside intermediate directory.
        if options.output_type == Build_Output_Type.EXECUTABLE {
            array_add(*arguments, tprint("/IMPLIB:%1%2.lib", options.intermediate_path, path_strip_extension(options.output_executable_name)));
        }
    } else if target_linux {
        array_add(*arguments, "--eh-frame-hdr");
        array_add(*arguments, "-export-dynamic");
        array_add(*arguments, tprint("-o%", target_filename));
        array_add(*arguments, "--dynamic-linker");
        array_add(*arguments, "/lib64/ld-linux-x86-64.so.2");
        array_add(*arguments, "-rpath=$ORIGIN");
    } else { // target_macosx
        array_add(*arguments, "-export_dynamic");
        array_add(*arguments, "-dynamic");
        array_add(*arguments, "-o");
        array_add(*arguments, target_filename);

        array_add(*arguments, "-macosx_version_min");
        array_add(*arguments, "10.11");

        array_add(*arguments, "-rpath");
        array_add(*arguments, "@loader_path"); // NOTE: on the command-line we have to single-quote this, here it must be unquoted!
    }

    // @TODO we probably need to do something similar using LLD on non-Windows hosts
    #if OS == .WINDOWS {
        if target_windows {
            vc_path := Windows_Resources.find_visual_studio_in_a_ridiculous_garbage_way();
            if vc_path {
                array_add(*arguments, tprint("/libpath:\"%\"", vc_path));
            } else {
                compiler_report(#file, #line, 0, "Unable to find Visual Studio runtime library folder; can't compile.\n");
            }

            kit_root, windows_version := Windows_Resources.find_windows_kit_root();
            if kit_root {
                // I guess both Windows 8 and 10 use the same um / ucrt format.
                // kit_root does not have a slash at the end!! Sigh.
                array_add(*arguments, tprint("/libpath:\"%/um/x64\"", kit_root));
                array_add(*arguments, tprint("/libpath:\"%/ucrt/x64\"", kit_root));
            } else {
                // Report error.
                compiler_report(#file, #line, 0, "Unable to find Windows Kit root; can't compile.\n");
            }


            if (options.output_type == Build_Output_Type.DYNAMIC_LIBRARY) {
                array_add(*arguments, "/DLL");
            }

            array_add(*arguments, "-nodefaultlib");
        }
    }

    for m.libraries    array_add(*arguments, it);


    // @Spam Uncomment this line to revert the compilation output containing all the linker
    // args.
    //print("Link line: %\n", concatenate(..arguments, " "));

    success, exit_code, out, err := os_run_command(..arguments, capture_and_return_output=true);


    // @Color I added some color codes to the output here.
    if (!success) || (exit_code != 0) {
        print("\n\n\e[1;31mError: Link step failed! (Exit code %).\n", exit_code);
        if err != ""  print("%\n", err);
        if out != ""  print("%\n", out);
        print("\e[0;36m");
    }
    else {
        displayed_something := false;
        for split(out, "\n") {
            line := trim(it, " \t\n\r");
            if line != "" && !starts_with(line, "Creating library") {
                if !displayed_something {
                    print("\n\n");
                    displayed_something = true;
                }
                print("%\n", line);
            }
        }
    }
    print("\e[0;36m");
    //print("\e[1;30m");

    // Report to the compiler that we have finished linking
    compiler_custom_link_command_is_complete(w);
}
