/* Alexandre Monteiro - 51023
*  Tiago Carvalho - 51034
*  Miguel Saldanha - 51072
*/
pragma solidity ^0.8.0;

contract Lease {
    
    enum State { CREATED, SIGNED, VALID, TERMINATED }
    
    address payable public Lessor;
    address payable public InsuranceCompany;
    address payable public Lessee;
    
    uint assetId;
    uint public val; //value of the asset
    uint public lifespan; //in cycles
    uint period; //length of each cycle
    uint public fineR; //in percentage
    uint public termFine; //in wei
    uint interestR; //in percentage
    uint dur; //in cycles
    uint public installmentsPaid; //in cycles
    uint public curResidual; //residual amount remaining to pay
    
    State public state;
    
    uint public pendingWithdrawal; 
    uint startTime;
    uint public lastPayment; //in cycles
    uint public cyclesPassed; //amount of cycles that have passed
    
    event Destroyed(uint asset, address insurance);
    event Ownership(address lessee, uint asset);
    
    //rule 1, deployment of smart contract
    constructor (address less, address insurance, uint identifier, uint value, uint life_span, uint periodicity, uint fineRate, uint terminationFine) {
        Lessor = payable(msg.sender); //deployer becomes the lessor
        assetId = identifier;
        val = value;
        lifespan = life_span;
        period = periodicity * 60; //periodicity is given in minutes bot stored in seconds
        fineR = fineRate; //fine rate in percentage
        termFine = terminationFine; //in wei
        state = State.CREATED;
        curResidual = 0;
        pendingWithdrawal = 0;
        cyclesPassed = 0;
        lastPayment = 0;
        installmentsPaid = 0;
        InsuranceCompany = payable(insurance); //definition of insurance company
        Lessee = payable(less); //definition of lessee
    }
    
    modifier inState(State s) {
        require(state == s, "Not in the proper state");
        _;
    }
    
    modifier updateTime() {
        cyclesPassed = (block.timestamp - startTime)/period;
        if(cyclesPassed >= lastPayment + 2) {
            state = State.TERMINATED;
        }
        _;
    }
    
    //updating the time
    function updateTimeFunc() public{
        cyclesPassed = (block.timestamp - startTime)/period;
        if(cyclesPassed >= lastPayment + 2) {
            state = State.TERMINATED;
        }
    }
    
    //rule 2, insurance company signs smart contract
    function signCompany(uint interestRate) inState(State.CREATED) public{
        require(payable(msg.sender) == InsuranceCompany);
        interestR = interestRate; //in percentage
        state = State.SIGNED;
    }
    
    //rule 3, lessee signs smart contract
    function signLessee(uint duration) inState(State.SIGNED) public{
        require(payable(msg.sender) == Lessee);
        dur = duration; //in cycles
        state = State.VALID;
        startTime = block.timestamp; //marks the beginning of the smart contract
        
        //calculation of the residual amount the lessee will have to pay to get ownership
        curResidual = val - ((val / lifespan) * dur); 
    }
    
    //rule 4, payment of rental by the lessee. Pays while inside the cycle
    function payRental() updateTime() inState(State.VALID) payable public{
        require(payable(msg.sender) == Lessee, "Only the Lessee can pay the Rental");
        
        //rule 8, the lessee pays the rental with the fine rate added. Fine rate is only paid to the lessor
        if(cyclesPassed >= lastPayment + 1) {
            require(msg.value >= getFine() + getMonthlyInsurance());
            pendingWithdrawal += getFine();
        }
        else { //the lessee pays the normal rental
            require(msg.value >= getRental());
            pendingWithdrawal += getMonthlyInstallment();
        }
        installmentsPaid += 1;
        payable(InsuranceCompany).transfer(getMonthlyInsurance()); //payment of monthly insurance
        
        if(installmentsPaid == dur) { //checking if lessee has paid all the installments required
            state = State.TERMINATED;
            if(curResidual == 0) { //if there's no residual value left, lessee owns the asset
                emit Ownership(msg.sender, assetId);
            }
            return;
        }
        
        //rule 6, payment of amortizations on residual value
        if(msg.value > getRental() && curResidual > 0) {
            if(curResidual > 0) {
                curResidual -= (msg.value - getRental()); //decreases the residual payment
            }
            else {
                payable(msg.sender).transfer(msg.value - getRental()); //sends excess value to sender
            }
        }
        lastPayment = cyclesPassed + 1;
    }
    
    //rule 7 and 11, lessee liquidates but does not pay residual value
    function liquidateLease() updateTime() inState(State.VALID) payable public { 
        require(payable(msg.sender) == Lessee, "Only the Lessee can pay the rental");
        
        // calculating the amount left to liquidate the lease, without monthly insurance, only the asset value
        uint valLeft = (dur - installmentsPaid) * getMonthlyInstallment();
        
        require(msg.value >= valLeft);
        pendingWithdrawal += valLeft;
        if(msg.value > valLeft){
            payable(msg.sender).transfer(msg.value - valLeft); //sends excess value to sender
        }
        state = State.TERMINATED;
    }
    
    //rule 10, lessee liquidates and pays the residual value, gaining ownership
    function getOwnership() updateTime() inState(State.VALID) payable public { 
        require(payable(msg.sender) == Lessee, "Only the Lesse can pay the residual");
        
        //calculating the amount left to liquidate the lease + the unpaid residual value
        uint valLeft = ((dur - installmentsPaid) * getMonthlyInstallment()) + curResidual;
        
        require(msg.value >= valLeft, "Not enough to pay for the entire asset");
        
        //emission of ownership event
        emit Ownership(msg.sender, assetId);
        
        pendingWithdrawal += valLeft;
        if(msg.value > valLeft) {
            payable(msg.sender).transfer(msg.value - valLeft); //sends excess value to sender
        }
        state = State.TERMINATED;
    }
    
    //rule 5, Lessor can withdraw from the smart contract, at any time
    function withdraw(uint quantity) public{
        require(payable(msg.sender) == Lessor, "Only the Lessor can withdraw");
        require(pendingWithdrawal > 0 && quantity <= pendingWithdrawal);
        
        payable(Lessor).transfer(quantity);
        pendingWithdrawal -= quantity;
    }
    
    //rule 9, termination rules
    function terminate() inState(State.VALID) payable public {
        require(payable(msg.sender) == Lessee, "Only the Lessee can terminate");
        
        //during first cycle
        if(cyclesPassed == 0) {
            //lessee doesn't have to pay since it's the first cycle
            if(msg.value > 0) {
                payable(msg.sender).transfer(msg.value); //sends excess value to sender
            }    
            state = State.TERMINATED;
        } else {
            require(msg.value >= termFine, "Not enough to terminate");
            
            //payment of termination fee
            pendingWithdrawal += termFine;
            
            state = State.TERMINATED;
            if(msg.value > termFine) {
                payable(msg.sender).transfer(msg.value - termFine); //sends excess value to sender
            }
        }
    }
    
    //rule 12, insurance company declares asset destroyed
    function declareDestroyed() inState(State.VALID) payable public { 
        require(payable(msg.sender) == InsuranceCompany, "Only the insurance Company can declare the asset destroyed");
        require(msg.value >= val);
        
        //insurance company gives the whole value of the asset to the lessor
        pendingWithdrawal += val;
        
        if(msg.value > val) {
            payable(msg.sender).transfer(msg.value - val); //sends excess value to sender
        }
        emit Destroyed(assetId,InsuranceCompany);
        state = State.TERMINATED;
    }
    
    function getMonthlyInstallment() public view returns(uint){
        return val/lifespan;
    }
    
    function getMonthlyInsurance() public view returns(uint){
        return ((val * interestR) / 100)/dur;
    }
    
    function getRental() public view returns(uint){
        return getMonthlyInstallment() + getMonthlyInsurance();
    }
    
    function getResidual() public view returns(uint){
        return val - (getMonthlyInstallment() * dur);
    }
    
    function getFine() public view returns(uint) {
        return (getMonthlyInstallment() * (100 + fineR)) / 100;
    }
}
