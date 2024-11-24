#[macro_export]
macro_rules! inst_arm {
    ($line:expr, $types:expr, $label:expr, $t:expr, $f:expr) => {{
        let params = Some(parse_params(params($line)));
        $types.push(Instruction {
            t: $t,
            flags: $f,
            label: $label.take(),
            params,
        });
    }};
}
