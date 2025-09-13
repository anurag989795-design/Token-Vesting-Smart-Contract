module MyModule::TokenVesting {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    
    /// Struct representing a token vesting schedule.
    struct VestingSchedule has store, key {
        total_amount: u64,      // Total tokens to be vested
        vested_amount: u64,     // Amount already claimed
        start_time: u64,        // Vesting start timestamp
        vesting_duration: u64,  // Duration in seconds
        beneficiary: address,   // Address that can claim tokens
    }
    
    /// Error codes
    const E_NOT_BENEFICIARY: u64 = 1;
    const E_VESTING_NOT_STARTED: u64 = 2;
    const E_NO_TOKENS_TO_CLAIM: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    
    /// Function to create a new vesting schedule.
    public fun create_vesting_schedule(
        creator: &signer, 
        beneficiary: address,
        total_amount: u64, 
        vesting_duration: u64
    ) {
        let creator_addr = signer::address_of(creator);
        let current_time = timestamp::now_seconds();
        
        // Transfer tokens from creator to contract
        let tokens = coin::withdraw<AptosCoin>(creator, total_amount);
        coin::deposit<AptosCoin>(creator_addr, tokens);
        
        let vesting_schedule = VestingSchedule {
            total_amount,
            vested_amount: 0,
            start_time: current_time,
            vesting_duration,
            beneficiary,
        };
        
        move_to(creator, vesting_schedule);
    }
    
    /// Function for vesting owner to release vested tokens to beneficiary.
    public fun release_vested_tokens(
        owner: &signer, 
        beneficiary_addr: address
    ) acquires VestingSchedule {
        let owner_addr = signer::address_of(owner);
        let vesting = borrow_global_mut<VestingSchedule>(owner_addr);
        
        // Check if the provided address matches the beneficiary
        assert!(vesting.beneficiary == beneficiary_addr, E_NOT_BENEFICIARY);
        
        let current_time = timestamp::now_seconds();
        assert!(current_time >= vesting.start_time, E_VESTING_NOT_STARTED);
        
        // Calculate vested amount
        let elapsed_time = current_time - vesting.start_time;
        let vested_amount = if (elapsed_time >= vesting.vesting_duration) {
            vesting.total_amount
        } else {
            (vesting.total_amount * elapsed_time) / vesting.vesting_duration
        };
        
        let claimable_amount = vested_amount - vesting.vested_amount;
        assert!(claimable_amount > 0, E_NO_TOKENS_TO_CLAIM);
        
        // Transfer tokens from owner to beneficiary
        let tokens = coin::withdraw<AptosCoin>(owner, claimable_amount);
        coin::deposit<AptosCoin>(beneficiary_addr, tokens);
        
        // Update vested amount
        vesting.vested_amount = vested_amount;
    }
}