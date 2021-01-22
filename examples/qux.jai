#import "Basic";

main :: () {
    print("f(%) = %\n", 3, factorial(3));
}

factorial :: (f: int) -> int, int {
    if f <= 1  return 1, 1;
    n := 1;
    for < f..2  n *= it;

    return n, n;
}
