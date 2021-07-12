Alexandre Monteiro - 51023
Tiago Carvalho - 51034
Miguel Saldanha - 51072

To deploy the smart contract, as the lessor, you need:
- Address of the lessee
- Address of the insurance company
- Identifier of the asset
- Value of the asset (in wei)
- Lifespan (in cycles)
- Periodicity (in minutes)
- Fine rate
- Termination fine

Then, the insurance company can sign the smart contract by giving their interest rate, using the function "signCompany".
With this done, the lessee can sign the contract by inputing the duration (in minutes) of the lease.

As a lessee, you can use the payRental function, passing along its due value in the message value. You can also pay more wei to amortize the residual value.
Other than that, you can use the function liquidateLease to fully pay the lease, without paying the residual value.
If the lessee wants to get ownership of the asset, they can use the function getOwnership to pay for the whole asset and acquire it.
All of these functions require the lessee to associate the needed value to the message. 
If the lessee sends money in excess it will either be returned to them or will amortize the residual value.
The fine rate is calculated only on the monthly installment.
The lesse can also use the function terminate, with an associated value required if one cycle has passed.

As a lessor, you can use the function withdraw to get wei from the smart contract.
This withdrawal can be done at any given time, as long as the smart contract possesses enough wei to meet the request.

As an insurance company, you can declare an asset destroyed. This requires the company to send the full value of the asset to the lessor.

All of the participants in the smart contract can use the getter functions as well as the updateTime, with no required values or parameters.

Public functions:
- declareDestroyed(): no parameters. Requires the whole value of the asset to be sent along with the message. Can only be called by the insurance company. Smart contract will be terminated.
                  Around 90k gas cost.
- getOwnership(): no parameters. Requires the remaining value of the lease plus the remaining residual value to be sent along with the message. Can only be called by the lessee.
                  Smart contract will be terminated and the lessee will get ownership of the asset. Around 70k gas cost.
- liquidateLease(): no parameters. Requires the remaning value of the lease to be sent along with the message (no residual value). Can only be called by the lessee.
                  Smart contract will be terminated but the lessee will not have ownership of the asset. Around 95k gas cost.
- payRental(): no parameters. Requires the value of rental to be sent along with the message. Any amount sent in excess will amortize the residual value.
                  If the lessee does not pay one cycle, they will have to pay a fine rate in the next (calculated on the monthly installment value). 
                  After two cycles unpaid, the contract will be terminated. After having paid all the installments, the contract will be terminated.
                  If the residual value is completely paid at the end of the lease, the lessee will get ownership of the asset. Around 120k gas cost, 240k gas cost if the payment is late.
- signCompany(uint interestRate): receives the interest rate (in percentage) as a parameter. Can only be called by the insurance company.
                  Changes the state of the smart contract from CREATED to SIGNED. Around 100k gas cost.
- signLessee(uint duration): receives the duration of the lease (in minutes) as a parameter. Can only be called by the lesse. Changes the state from SIGNED to VALID. Around 160k gas cost.
- terminate(): no parameters. Can only be called by the lessee. If the contract is still in its first cycle, nothing is required. 
                  After the first cycle, the lessee needs to send the termination fee to terminate the contract. Around 38k gas cost, around 55k gas cost if more than one cycle has passed.
- updateTimeFunc(): no parameters. Anyone can call this function. Calculates current cycle, can change the state of the contract to TERMINATED. Around 30k gas cost.
- withdraw(uint quantity): receives the amount to be withdrawn as a parameter. Can only be called by the lessor. 
                  Transfers the amount to the lessor as long as the smart contract has enough to meet the request. Around 40k gas cost.
- getMonthlyInstallment(): no parameters. Returns the monthly installment (value / lifespan). Around 25k gas cost.
- getMonthlyInsurance(): no parameters. Returns the monthly insurance ((value * insuranceRate) / duration). Around 27k gas cost.
- getRental(): no parameters. Returns the rental (monthlyInstallment + monthlyInsurance). Around 31k gas cost.
- getResidual(): no parameters. Returns the residual value (value - (monthlyInstallment * duration)). Around 29k gas cost.
- getFine(): no parameters. Returns the monthlyInstallment with added fee (monthlyInstallment * fineRate). Around 28k gas cost.

Deployment cost is around 4.5 millions.








