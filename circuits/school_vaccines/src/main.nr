// Proves a student's vaccine record meets a school's dose requirements
// without revealing the record.
//
// Private: dose counts per vaccine and a random salt.
// Public:  the school's minimum doses, the student's Ledger address,
//          and (returned) a commitment to the hidden record.
//
// Vaccine order: DTaP, Polio, MMR, Varicella, Hepatitis B, Hepatitis A, Tdap
global VACCINES: u32 = 7;

fn main(
    doses: [u8; VACCINES],
    salt: Field,
    min_doses: pub [u8; VACCINES],
    holder: pub Field,
) -> pub Field {
    for i in 0..VACCINES {
        assert(doses[i] >= min_doses[i], "vaccine requirement not met");
    }
    // Binds the proof to one student's Ledger address.
    assert(holder != 0);
    commitment(doses, salt, holder)
}

fn commitment(doses: [u8; VACCINES], salt: Field, holder: Field) -> Field {
    let mut inputs: [Field; VACCINES + 2] = [0; VACCINES + 2];
    for i in 0..VACCINES {
        inputs[i] = doses[i] as Field;
    }
    inputs[VACCINES] = salt;
    inputs[VACCINES + 1] = holder;
    std::hash::pedersen_hash(inputs)
}

#[test]
fn meets_requirements() {
    let _ = main([5, 4, 2, 2, 3, 2, 1], 42, [5, 4, 2, 2, 3, 2, 1], 0xdad77910dbdfde764fc21fcd4e74d71bbaca6d8d);
}

#[test(should_fail_with = "vaccine requirement not met")]
fn missing_mmr_dose() {
    let _ = main([5, 4, 1, 2, 3, 2, 1], 42, [5, 4, 2, 2, 3, 2, 1], 0xdad77910dbdfde764fc21fcd4e74d71bbaca6d8d);
}

#[test]
fn salt_changes_commitment() {
    let a = commitment([5, 4, 2, 2, 3, 2, 1], 1, 7);
    let b = commitment([5, 4, 2, 2, 3, 2, 1], 2, 7);
    assert(a != b);
}
