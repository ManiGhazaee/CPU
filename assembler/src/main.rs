use clap::Parser;
use core::panic;
use std::{collections::HashMap, fs, vec};

mod macros;

#[derive(Parser, Debug, Clone)]
#[command(version, about, long_about = "")]
#[command(next_line_help = true)]
pub struct Config {
    /// Source assembly file path
    #[arg(long, short)]
    pub src: String,

    /// Destination file path, if it is not provided it will print the result
    #[arg(long, short)]
    pub dest: Option<String>,

    /// Length of the memory 
    #[arg(long, short, default_value_t = 256)]
    pub len: usize,
}

fn main() {
    let config = Config::parse();
    let src = config.src;
    let file = fs::read_to_string(src).unwrap();
    let file = remove_comments(&file);

    let insts = parse_asm(&file);

    let bin: Vec<Bin> = Bin::from(&insts, 0);
    let finalized = finalize_bin(bin, config.len);
    let hexedln = bin_hexedln(finalized);

    if let Some(dest) = config.dest {
        fs::write(dest, hexedln).unwrap();
    } else {
        println!("{}", hexedln);
    }
}

fn remove_comments(src: &str) -> String {
    let mut res = String::new();
    let bytes = src.as_bytes();
    let mut i = 0;
    while i < bytes.len() - 1 {
        if bytes[i] == b'/' && bytes[i + 1] == b'/' {
            while bytes[i] != b'\n' {
                i += 1;
            }
        }
        res.push(bytes[i] as char);
        i += 1;
    }
    res.push(bytes[bytes.len() - 1] as char);
    res
}

fn bin_hexedln(bin: Vec<Bin>) -> String {
    bin.into_iter()
        .map(|i| format!("{}\n", String::from_utf8(hex_encode(i.word)).unwrap()))
        .collect()
}

fn finalize_bin(mut bin: Vec<Bin>, len: usize) -> Vec<Bin> {
    let mut pointers: HashMap<String, Vec<usize>> = Default::default();
    let mut pointees: HashMap<String, usize> = Default::default();
    for (idx, i) in bin.iter().enumerate() {
        if let Some(s) = &i.pointee {
            pointees.insert(s.to_owned(), idx);
        }
        if let Some(p) = &i.pointer {
            for s in p {
                if let Some(p) = pointers.get_mut(s) {
                    p.push(idx);
                } else {
                    pointers.insert(s.to_owned(), vec![idx]);
                }
            }
        }
    }

    for i in pointers {
        let address = *pointees.get(&i.0).expect("label error") as u32;
        for a in i.1 {
            bin[a].word |= address;
        }
    }

    if bin.len() == len {
        bin
    } else if bin.len() > len {
        panic!(
            "generated binary has len greater than the len provided\nbin len: {}\nlen: {}",
            bin.len(),
            len
        );
    } else {
        for _ in 0..(len - bin.len()) {
            bin.push(Bin {
                word: 0,
                pointer: None,
                pointee: None,
            });
        }
        bin
    }
}

fn parse_asm(src: &str) -> Vec<Instruction> {
    let mut insts = Vec::new();
    let mut label: Option<String> = None;
    'l: for line in src.trim().lines() {
        let line = line.trim();
        let splitted = line.split_whitespace().collect::<Vec<_>>();
        let word = if let Some(&word) = splitted.get(0) {
            word
        } else {
            continue;
        };

        if word.starts_with("$") {
            for i in 1..line.len() {
                if line.as_bytes()[i] == b':' {
                    let l = line[1..i].trim().to_string();
                    label = Some(l);
                    break;
                }
            }
            continue 'l;
        }

        match word {
            ".zero" => inst_arm!(
                line,
                insts,
                label,
                InstType::Dot(word.to_string()),
                Flags::NONE
            ),
            ".data" => inst_arm!(
                line,
                insts,
                label,
                InstType::Dot(word.to_string()),
                Flags::NONE
            ),
            "and" => inst_arm!(line, insts, label, InstType::And, Flags::NONE),
            "or" => inst_arm!(line, insts, label, InstType::Or, Flags::NONE),
            "inc" => inst_arm!(line, insts, label, InstType::Inc, Flags::NONE),
            "dec" => inst_arm!(line, insts, label, InstType::Dec, Flags::NONE),
            "add" => inst_arm!(line, insts, label, InstType::Add, Flags::NONE),
            "sub" => inst_arm!(line, insts, label, InstType::Sub, Flags::NONE),
            "xor" => inst_arm!(line, insts, label, InstType::Xor, Flags::NONE),
            "not" => inst_arm!(line, insts, label, InstType::Not, Flags::NONE),
            "shr" => inst_arm!(line, insts, label, InstType::Shr, Flags::NONE),
            "ashr" => inst_arm!(line, insts, label, InstType::Ashr, Flags::NONE),
            "ror" => inst_arm!(line, insts, label, InstType::Ror, Flags::NONE),
            "rcr" => inst_arm!(line, insts, label, InstType::Rcr, Flags::NONE),
            "shl" => inst_arm!(line, insts, label, InstType::Shl, Flags::NONE),
            "ashl" => inst_arm!(line, insts, label, InstType::Ashl, Flags::NONE),
            "rol" => inst_arm!(line, insts, label, InstType::Rol, Flags::NONE),
            "rcl" => inst_arm!(line, insts, label, InstType::Rcl, Flags::NONE),
            "hlt" => inst_arm!(line, insts, label, InstType::Hlt, Flags::NONE),
            "lac" => inst_arm!(line, insts, label, InstType::Lac, Flags::NONE),
            "laci" => inst_arm!(line, insts, label, InstType::Lac, Flags(vec!['i'])),
            "ltr" => inst_arm!(line, insts, label, InstType::Ltr, Flags::NONE),
            "wac" => inst_arm!(line, insts, label, InstType::Wac, Flags::NONE),
            "rac" => inst_arm!(line, insts, label, InstType::Rac, Flags::NONE),
            "jmp" => inst_arm!(line, insts, label, InstType::Jmp, Flags::NONE),
            "je" => inst_arm!(line, insts, label, InstType::Je, Flags::NONE),
            "jne" => inst_arm!(line, insts, label, InstType::Jne, Flags::NONE),
            "jg" => inst_arm!(line, insts, label, InstType::Jg, Flags::NONE),
            "jl" => inst_arm!(line, insts, label, InstType::Jl, Flags::NONE),
            "jmpi" => inst_arm!(line, insts, label, InstType::Jmp, Flags(vec!['i'])),
            "jei" => inst_arm!(line, insts, label, InstType::Je, Flags(vec!['i'])),
            "jnei" => inst_arm!(line, insts, label, InstType::Jne, Flags(vec!['i'])),
            "jgi" => inst_arm!(line, insts, label, InstType::Jg, Flags(vec!['i'])),
            "jli" => inst_arm!(line, insts, label, InstType::Jl, Flags(vec!['i'])),
            "out" => inst_arm!(line, insts, label, InstType::Out, Flags::NONE),
            "ion" => inst_arm!(line, insts, label, InstType::Ion, Flags::NONE),
            "iof" => inst_arm!(line, insts, label, InstType::Iof, Flags::NONE),
            "nop" => inst_arm!(line, insts, label, InstType::Nop, Flags::NONE),
            _ => panic!("unknown instruction {word}"),
        }
    }
    insts
}

#[derive(Debug)]
struct Instruction {
    t: InstType,
    flags: Flags,
    label: Option<String>,
    params: Option<Vec<Param>>,
}

#[derive(Debug, Clone)]
struct Bin {
    word: u32,
    pointer: Option<Vec<String>>,
    pointee: Option<String>,
}

impl Bin {
    pub fn new(word: u32, pointer: Option<Vec<String>>, pointee: Option<String>) -> Self {
        Self {
            word,
            pointer,
            pointee,
        }
    }
}

impl Bin {
    pub fn from(src: &[Instruction], offset: u32) -> Vec<Self> {
        let mut bin = Vec::new();
        let mut _offset = offset;
        for i in src {
            if let Some(b) = match &i.t {
                InstType::Dot(s) => match s.as_ref() {
                    ".zero" => Some(vec![Bin::new(0, None, i.label.clone())]),
                    ".data" => match &i.params.as_ref().unwrap()[0] {
                        Param::String(s) => Some(
                            s.chars()
                                .enumerate()
                                .map(|(idx, ch)| {
                                    if idx == 0 {
                                        Bin::new(ch as u8 as u32, None, i.label.clone())
                                    } else {
                                        Bin::new(ch as u8 as u32, None, None)
                                    }
                                })
                                .collect(),
                        ),
                        Param::Label(s) => Some(vec![Bin::new(
                            0,
                            Some(vec![s.to_string()]),
                            i.label.clone(),
                        )]),
                        Param::Value(s) => {
                            let value = parse_value(s);
                            Some(vec![Bin::new(value as u32, None, i.label.clone())])
                        }
                        _ => panic!(".data invalid parameter {:?}", i.params.as_ref()),
                    },
                    _ => todo!(),
                },
                _ => None::<Vec<Bin>>,
            } {
                for b in b {
                    bin.push(b);
                }
            } else {
                let opcode = match &i.t {
                    InstType::And => 0,
                    InstType::Or => 1,
                    InstType::Inc => 2,
                    InstType::Dec => 3,
                    InstType::Add => 4,
                    InstType::Sub => 5,
                    InstType::Xor => 6,
                    InstType::Not => 7,
                    InstType::Shr => 8,
                    InstType::Ashr => 9,
                    InstType::Ror => 10,
                    InstType::Rcr => 11,
                    InstType::Shl => 12,
                    InstType::Ashl => 13,
                    InstType::Rol => 14,
                    InstType::Rcl => 15,
                    InstType::Wac => 16,
                    InstType::Jmp => 17,
                    InstType::Je => 18,
                    InstType::Jne => 19,
                    InstType::Jg => 20,
                    InstType::Jl => 21,
                    InstType::Rac => 22,
                    InstType::Nop => 121,
                    InstType::Iof => 122,
                    InstType::Ion => 123,
                    InstType::Out => 124,
                    InstType::Ltr => 125,
                    InstType::Lac => 126,
                    InstType::Hlt => 127,
                    InstType::Dot(_) => todo!(),
                };
                let indirect = i.flags.0.contains(&'i');
                let b: Vec<Bin> = match &i.params.as_ref().unwrap()[0] {
                    Param::Value(s) => {
                        let value = parse_value(s);
                        vec![Bin::new(
                            inst_word(value as u32, opcode, indirect as u32),
                            None,
                            i.label.clone(),
                        )]
                    }
                    Param::Indirect(s) => {
                        let value = parse_value(s);
                        vec![Bin::new(
                            inst_word(value as u32, opcode, 1),
                            None,
                            i.label.clone(),
                        )]
                    }
                    Param::Label(s) => {
                        vec![Bin::new(
                            inst_word(0, opcode, indirect as u32),
                            Some(vec![s.to_string()]),
                            i.label.clone(),
                        )]
                    }
                    Param::Calc(_param) => {
                        todo!()
                    }
                    Param::String(_) => panic!("{:?} invalid parameter", i.t),
                };
                for b in b {
                    bin.push(b);
                }
            };
            _offset += 1;
        }
        bin
    }
}

fn parse_value(src: &str) -> u32 {
    if src.starts_with("0x") {
        hex_decode(src.as_bytes()).unwrap() as u32
    } else if src.starts_with("0d") {
        src[2..].parse().unwrap()
    } else if src.trim().is_empty() {
        0
    } else {
        todo!()
    }
}

fn inst_word(value: u32, opcode: u32, i: u32) -> u32 {
    let mut res = 0;
    res = res | i;
    res = (res << 7) | opcode;
    res = (res << 24) | value;
    res
}

impl Instruction {}

#[derive(Debug)]
struct Flags(Vec<char>);

impl Flags {
    const NONE: Self = Self(Vec::new());
}

#[derive(Debug)]
enum InstType {
    Dot(String),
    And,
    Or,
    Inc,
    Dec,
    Add,
    Sub,
    Xor,
    Not,
    Shr,
    Ashr,
    Ror,
    Rcr,
    Shl,
    Ashl,
    Rol,
    Rcl,
    /// halt the entire process
    Hlt,
    /// load accumulator register
    Lac,
    /// load temporary register
    Ltr,
    /// write accumulator register to mem at param0
    Wac,
    /// read memory at accumulator to accumulator
    Rac,
    /// jmp unconditional
    Jmp,
    /// jmp if zero flag == 1
    Je,
    /// jmp if zero flag == 0
    Jne,
    /// jmp if sign flag == 0
    Jg,
    /// jmp if sign flag == 1
    Jl,
    // send accumulator register's value to output register
    Out,
    // set interrupt enable to true
    Ion,
    // set interrupt enable to false
    Iof,
    // no operation
    Nop,
}

#[allow(unused)]
#[derive(Debug)]
enum Param {
    Calc(Box<Param>),
    Value(String),
    Label(String),
    Indirect(String),
    String(String),
}

fn parse_params(v: Vec<String>) -> Vec<Param> {
    let mut res = Vec::new();
    for s in v {
        let s = s.trim();
        if s.starts_with("%") {
            match &s[1..] {
                _ => panic!("unknown register"),
            }
        } else if s.starts_with("$") {
            res.push(Param::Label(s[1..].trim().to_string()));
        } else if s.starts_with("[") && s.ends_with("]") {
            res.push(Param::Indirect(s[1..s.len() - 1].to_string()));
        } else if s.starts_with("\"") && s.ends_with("\"") {
            res.push(Param::String(s[1..s.len() - 1].to_string()));
        } else {
            res.push(Param::Value(s.trim().to_string()));
        }
    }
    res
}

fn params(line: &str) -> Vec<String> {
    let line = line.trim();
    let line_len = line.len();
    let mut start = 0;
    for (idx, ch) in line.chars().enumerate() {
        if ch == ' ' || idx == line_len - 1 {
            start = idx + 1;
            break;
        }
    }
    // let x = line.split_whitespace().skip(1).collect::<Vec<&str>>();
    // let joined = x.iter().map(|i| i.to_string()).collect::<String>();
    let params_str = line[start..].trim();
    let mut is_string = false;
    let mut escape = false;
    let mut res = Vec::new();
    let mut tmp = String::new();
    for ch in params_str.chars() {
        if ch == '\\' {
            escape = true;
            continue;
        }

        if ch == '"' && escape {
            escape = false;
        } else if ch == '"' && !escape {
            is_string = !is_string;
        }
        if !is_string && ch == ',' {
            res.push(tmp.clone());
            tmp.clear();
            continue;
        }
        if ch == 'n' && escape {
            escape = false;
            tmp.push('\n');
            continue;
        }
        tmp.push(ch);
    }
    res.push(tmp.clone());
    // joined
    // .split(',')
    // .map(|i| i.to_string())
    // .collect::<Vec<String>>()
    res
}

fn hex_encode(mut src: u32) -> Vec<u8> {
    let mask: u32 = 15;
    let mut res: Vec<u8> = Vec::with_capacity(8);
    for _ in 0..8 {
        let byte = match mask & src {
            0 => b'0',
            1 => b'1',
            2 => b'2',
            3 => b'3',
            4 => b'4',
            5 => b'5',
            6 => b'6',
            7 => b'7',
            8 => b'8',
            9 => b'9',
            10 => b'A',
            11 => b'B',
            12 => b'C',
            13 => b'D',
            14 => b'E',
            15 => b'F',
            _ => unreachable!(),
        };
        res.push(byte);
        src = src >> 4;
    }
    res.reverse();
    res
}

fn hex_decode(src: &[u8]) -> Result<usize, ()> {
    if src.len() == 0 {
        return Err(());
    }
    let mut res: usize = 0;
    for &char in src.iter() {
        let char = char as char;
        if char == 'x' {
            continue;
        }
        let d: usize = match char {
            '0' => 0,
            '1' => 1,
            '2' => 2,
            '3' => 3,
            '4' => 4,
            '5' => 5,
            '6' => 6,
            '7' => 7,
            '8' => 8,
            '9' => 9,
            'A' | 'a' => 10,
            'B' | 'b' => 11,
            'C' | 'c' => 12,
            'D' | 'd' => 13,
            'E' | 'e' => 14,
            'F' | 'f' => 15,
            _ => return Err(()),
        };
        res = (res << 4) | d;
    }
    Ok(res)
}

#[cfg(test)]
mod test {
    use crate::{hex_decode, hex_encode};

    #[test]
    fn test_hex_decode() {
        assert_eq!(hex_decode("26FDC4A9".as_bytes()), Ok(654165161));
        assert_eq!(hex_decode("0x1FFAB35FDC04".as_bytes()), Ok(35161611688964));
        assert_eq!(hex_decode("0".as_bytes()), Ok(0));
        assert_eq!(hex_decode("".as_bytes()), Err(()));
    }

    #[test]
    fn test_hex_encode() {
        assert_eq!(hex_encode(93482348), "05926D6C".as_bytes());
        assert_eq!(hex_encode(0), "00000000".as_bytes());
        assert_eq!(hex_encode(10010101), "0098BDF5".as_bytes());
    }
}
