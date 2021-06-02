// Example for `make_constructors.jai`
// Don't compile this directly; compile `make_constructors_example.jai` instead.


#import "Basic";


main :: () {
    foo := make_foo(100, 200, 1.5, "Hello");
    bar := make_bar("World", 500);
    log("%", foo);
    log("%", bar);
}


Foo :: struct {
    alpha : int;
    beta := 100;
    gamma : float32;
    delta : string;
}


Bar :: struct {
    name : string;
    count := -1;
}
