
__new_command_line_strings : [3] string : .[
    "C:\\repos\\jai-cookbook\\scripts\\jecho.jai",
    "Hello",
    "World",
];
__new_command_line_arguments : [3] *u8;
#run {
    __new_command_line_arguments[0] = __new_command_line_strings[0].data;
    __new_command_line_arguments[1] = __new_command_line_strings[1].data;
    __new_command_line_arguments[2] = __new_command_line_strings[2].data;
    __command_line_arguments.data = __new_command_line_arguments.data;
    __command_line_arguments.count = __new_command_line_arguments.count;
}
#run main();
