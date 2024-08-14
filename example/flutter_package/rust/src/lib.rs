#[cfg(feature = "sum")]
#[no_mangle]
pub extern "C" fn sum(a: usize, b: usize) -> usize {
    println!("Hello from rust {a} + {b}");
    a + b
}

#[cfg(all(test, feature = "sum"))]
mod tests {
    use super::*;

    #[test]
    fn it_works() {
        let result = sum(2, 2);
        assert_eq!(result, 4);
    }
}
