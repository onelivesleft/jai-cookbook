// This file gives an example for each compiler directive


// #add_context
// Adds a declaration to the context which is passed around your entire program.
#add_context this_is_the_way := true;

main :: () {
    query :: () {
        print("This is the way: %\n", context.this_is_the_way);
    }
    query();



    big : [16] u8 #align 64;
    big[0] = 1;
    big[1] = 2;
    print("size = %, value = %\n", size_of(type_of(big)), formatInt(big[0], base = 2));

    print("%\n%\n", #file, #filepath);
}


#import "Basic";

/*

#add_context        Add a declaration to the context
#align              ?
#assert             compiler-time assert
#bake               currying
#bake_arguments     currying
#c_call             is a call to a c library?
#caller_location    use as default value of parameter to set it to source code location
#char               Character literal
#code               code block
#compiler           proc is internal to compiler
#complete           Ensure an if-case satement checks all values of the enum
#expand             macro
#file               path+filename of running executable
#filepath           path of the running executable
#foreign            proc is a foreign function
#foreign_library    specify file for foreign functions
#foreign_system_library specify system file for foreign functions
#if                 compile-time if
#import             Import a module
#insert             insert string
#insert_internal    insert string internal to proc?
#intrinsic          proc is an intrinsic
#load               Load source code, as if it were placed right here (very commonly used)
#modify             filter polymorphic parameter type
#module_parameters  ?
#must               Require a return value to be assigned to a variable
#no_abc             No array-bounds-check
#no_alias           ?
#no_padding         no padding in struct
#place              set location in struct of following members
#placeholder        placeholder identifier to be filled out at compile time
#program_export
#run                Run this code right now (compile time)
#run_and_insert     @deprecated
#runtime_support    proc comes from runtime support
#scope_export       Set the scope for future declarations to be accessible by code that imports this module
#scope_file         Set the scope for foture declarations to just this file
#scope_module       Set the scope for foture declarations to just this module
#specified          Declare intention of maintaining enum values compatibility over time
#string             String literal with delimiter
#symmetric          proc is symmetric
#through            case has fall-through
#type               Type literal, e.g. for function types
#type_info_none     struct does not keep runtime type info
#type_info_procedures_are_void_pointers

*/
