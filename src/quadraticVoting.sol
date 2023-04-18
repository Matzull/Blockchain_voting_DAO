// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.0;

import "./token_ERC20.sol";
import "./IExecutableProposal.sol";

/*En la creacion de este contrato se debe proporcionar el precio en Wei de cada token y
el numero maximo de tokens que se van a poner a la venta para votaciones. Entre otras
cosas, el constructor debe crear el contrato de tipo ERC20 que gestiona los tokens. En
la secci ́on 3 se proporcionan m ́as detalles sobre el codigo del estandar ERC20.*/
contract quadraticVoting is Ownable{
    

    uint private tokenPrice = 300000;// 1 token = 300000 wei ≃ 5,5 eur
    uint private tokenAmount = 1000000;
    uint256 private totalBudget;

    bool private isVotingOpen;

    Stoken private token;

    struct t_proposal
    {
        string title;
        string description; 
        uint budget;
        uint voteAmount;
        uint currentBudget;
        mapping (address => uint) _voters;
        address[] _votersId;
        IExecutableProposal proposal;
        bool valid; //This field is true if the proposal has been canceled or approved
    }

    uint numberOfProposals;
    mapping (uint => t_proposal) _proposals;//Maps a proposal to its id
    //The following arrays keep track of the corresponding proposal ids in the _proposals mapping 
    uint[] _SignalingProposals;
    uint[] _ApprovedProposals;//Proposals in this array are also marked as (valid => false)
    uint[] _PendingProposals;

    uint _numberOfParticipants;
    mapping (address => address) _participants;    

    constructor() payable
    {
        token = new Stoken(0);
        owner(msg.sender());
        numberOfProposals = 1;//We start in one to keep 0 as the error code
        totalBudget += msg.value();
    }

    
    /*openVoting(): Apertura del periodo de votaci ́on. Solo lo puede ejecutar el usuario que
    ha creado el contrato. En la transacci ́on que ejecuta esta funci ́on se debe transferir el
    presupuesto inicial del que se va a disponer para financiar propuestas. Recuerda que
    este presupuesto total se modificar ́a cuando se aprueben propuestas: se incrementar ́a
    con las aportaciones en tokens de los votos de las propuestas que se vayan aprobando
    y se decrementar ́a por el importe que se transfiere a las propuestas que se aprueben.*/
    
    function openVoting() onlyOwner payable
    {
        totalBudget = msg.value();
        isVotingOpen = true;
    }


    /*addParticipant(): Funci ́on que utilizan los participantes para inscribirse en la votaci ́on.
    Los participantes se pueden inscribir en cualquier momento, incluso antes de que se abra
    el periodo de votaci ́on. Cuando se inscriben, los participantes deben transferir Ether
    para comprar tokens (al menos un token) que utilizar ́an para realizar sus votaciones.
    Esta funci ́on debe crear y asignar los tokens que se pueden comprar con ese importe. */
    
    function addParticipant() public payable 
    {
        require(
                msg.value() >= tokenPrice,
                "Not enough Ether to purchase 1 token" 
        );
        token.mint(msg.sender(), msg.value() / tokenPrice);
        _participants[msg.sender()] = msg.sender();
        _numberOfParticipants++;
    }


    /*removeParticipant(): Funci ́on para que un participante pueda eliminarse del sistema.
    Un participante que invoca esta funci ́on no podr ́a depositar votos, crear propuestas ni
    comprar o vender tokens, a no ser que se vuelva a a ̃nadir como participante. */
    
    function removeParticipant()
    {
        _participants[msg.sender()] = 0;
        _numberOfParticipants--;
    }


    /* addProposal(): Funci ́on que crea una propuesta. Cualquier participante puede crear pro-
    puestas, pero solo cuando la votaci ́on est ́a abierta. Recibe todos los atributos de la
    propuesta: t ́ıtulo, descripci ́on, presupuesto necesario para llevar a cabo la propuesta
    (puede ser cero si es una propuesta de signaling) y la direcci ́on de un contrato que im-
    plemente el interfaz ExecutableProposal, que ser ́a el receptor del dinero presupuestado
    en caso de ser aprobada la propuesta. Debe devolver un identificador de la propuesta
    creada.*/

    function addProposal(string title, string description, uint budget, address proposalAddress) public VotingClosed returns (uint)
    {
        _proposals[numberOfProposals] = new t_proposal(title, description, budget, 0, 0, IExecutableProposal(proposalAddress), true);
        if (budget == 0) {//If budget is 0 it is a signaling proposal
            //We save the signaling proposal id into _SignalingProposals array
            _SignalingProposals[_SignalingProposals.length] = numberOfProposals;
        } else {
            //We save the proposal id into _PendingProposals array
            _PendingProposals[_SignalingProposals.length] = numberOfProposals;
        }
        return numberOfProposals++;
    }


    /* cancelProposal(): Cancela una propuesta dado su identificador. Solo se puede ejecutar
    si la votaci ́on est ́a abierta. El  ́unico que puede realizar esta acci ́on es el creador de la
    propuesta. No se pueden cancelar propuestas ya aprobadas. Los tokens recibidos hasta
    el momento para votar la propuesta deben ser devueltos a sus propietarios.*/

    function cancelProposal(uint proposalId) OnlyCreator
    {
        returnFunds(_proposals[proposalId]);
        _proposals[proposalId].valid = false;
    }

    /*buyTokens(): Esta funci ́on permite a un participante ya inscrito comprar m ́as tokens para
    depositar votos. */

    function buyTokens() public payable
    {
        token.mint(msg.sender(), msg.value() / tokenPrice);
    }


    /* sellTokens(): Operaci ́on complementaria a la anterior: permite a un participante devol-
    ver tokens no gastados en votaciones y recuperar el dinero invertido en ellos.*/
    
    function sellTokens(uint amount) public
    {
        require(token.balanceOf(msg.sender()) >= amount, "Not enough tokens to sell");
        payable(msg.sender()).transfer(amount);
        token.burn(msg.sender(), amount / tokenPrice);
    }


    /*getERC20(): Devuelve la direcci ́on del contrato ERC20 que utiliza el sistema de votaci ́on
    para gestionar tokens. De esta forma, los participantes pueden utilizarlo para operar
    con los tokens comprados (transferirlos, cederlos, etc.).*/

    function getERC20()
    {
       return address(token);
    }


    /* getPendingProposals(): Devuelve un array con los identificadores de todas las propues-
    tas de financiaci ́on pendientes de aprobar. Solo se puede ejecutar si la votaci ́on est ́a
    abierta.*/

    function getPendingProposals() public VotingOpen returns (uint[] memory) 
    {
        return _PendingProposals;
    }

    /*getApprovedProposals(): Devuelve un array con los identificadores de todas las propues-
    tas de financiaci ́on aprobadas. Solo se puede ejecutar si la votaci ́on est ́a abierta. */

    function getApprovedProposals() public VotingOpen returns (uint[] memory)
    {
        return _ApprovedProposals;
    }


    /*getSignalingProposals(): Devuelve un array con los identificadores de todas las pro-
    puestas de signaling (las que se han creado con presupuesto cero). Solo se puede ejecutar
    si la votaci ́on est ́a abierta. */
    
    function getSignalingProposals() public VotingOpen returns (uint[] memory)
    {
        return _SignalingProposals;
    }


    /*getProposalInfo(): Devuelve los datos asociados a una propuesta dado su identificador.
    Solo se puede ejecutar si la votaci ́on est ́a abierta. */
    
    function getProposalInfo(uint proposalId) public VotingOpen returns (t_proposal memory)
    {
       return _proposals[proposalId]; 
    }
    
    
    /* stake(): recibe un identificador de propuesta y la cantidad de votos que se quieren de-
    positar y realiza el voto del participante que invoca esta funci ́on. Calcula los tokens
    necesarios para depositar los votos que se van a depositar y comprueba que el parti-
    cipante ha cedido (con approve) el uso de esos tokens a la cuenta del contrato de la
    votaci ́on. Recuerda que un participante puede votar varias veces (y en distintas llama-
    das a stake) una misma propuesta con coste total cuadr ́atico.
    El c ́odigo de esta funci ́on debe transferir la cantidad de tokens correspondiente desde
    la cuenta del participante a la cuenta de este contrato QuadraticVoting para poder
    operar con ellos. Como esta transferencia la realiza este contrato, el votante debe haber
    cedido previamente con approve los tokens correspondientes a este contrato (esa cesi ́on
    de tokens no se debe programar en QuadraticVoting: la debe realizar el participante
    con el contrato ERC20 antes de ejecutar esta funci ́on; el contrato ERC20 se puede
    obtener con getERC20).*/
    
    function stake(uint proposalId, uint votes) public
    {
        uint currentVotes = _proposals[proposalId]._voters[msg.sender()];
        uint price = mul(currentVotes + votes, currentVotes + votes) - mul(currentVotes, currentVotes);
        
        token.transferFrom(msg.sender(), address(this), price);
        _proposals[proposalId]._voters[msg.sender()] += votes;
        _proposals[proposalId].voteAmount += votes;
        _proposals[proposalId]._votersId[_proposals[proposalId]._votersId.length] = msg.sender();//If the voter already exists it creates a new id for the same voter
        _checkAndExecuteProposal(proposalId, _proposals[proposalId].voteAmount);
    }


    /*withdrawFromProposal(): Dada una cantidad de votos y el identificador de la propuesta,
    retira (si es posble) esa cantidad de votos depositados por el participante que invoca esta
    funci ́on de la propuesta recibida. Un participante solo puede retirar de una propuesta
    votos que  ́el haya depositado anteriormente y la propuesta no ha sido aprobada o
    cancelada. Recuerda que debes devolver al participante los tokens que utiliz ́o para
    depositar los votos que ahora retira (por ejemplo, si hab ́ıa depositado 4 votos a una
    propuesta y retira 2, se le deben devolver 12 tokens). */
    
    function withdrawFromProposal(uint proposalId, uint votes) public VotingOpen proposalNotApproved(proposalId)
    {
        uint currentVotes = _proposals[proposalId]._voters[msg.sender()];
        require(
                currentVotes >= votes,
                "Not enoughVotes to withdraw"
        );
        uint price = mul(currentVotes, currentVotes) - mul(currentVotes - votes, currentVotes - votes);
        token.transferFrom(address(this), msg.sender(), price);
        _proposals[proposalId]._voters[msg.sender()] -= votes;
        _proposals[proposalId].voteAmount -= votes;
    }
    

    /*_checkAndExecuteProposal(): Funci ́on interna que comprueba si se cumplen las con-
    diciones para ejecutar una propuesta de financiaci ́on y si es as ́ı la ejecuta utilizando
    la funci ́on executeProposal del contrato externo proporcionado al crear la propuesta.
    En esta llamada debe transferirse a dicho contrato el dinero presupuestado para su
    ejecuci ́on. Recuerda que debe actualizarse el presupuesto disponible para propuestas
    (y no olvides a ̃nadir al presupuesto el importe recibido de los tokens de votos de la
    propuesta que se acaba de aprobar). Adem ́as deben eliminarse los tokens asociados a
    los votos recibidos por la propuesta, pues la ejecuci ́on de la propuesta los consume.
    Las propuestas de signaling no se aprueban durante el proceso de votaci ́on: se ejecutan
    todas cuando se cierra el proceso con closeVoting. Cuando se realice la llamada a executeProposal del contrato externo, se debe limitar la
    cantidad m ́axima de gas que puede utilizar para evitar que la propuesta pueda consumir
    todo el gas de la transacci ́on. Esta llamada debe consumir como m ́aximo 100000 gas. */
    
    function _checkAndExecuteProposal(uint proposalId, uint votes) notSignalingProposal
    {
        //checking thresholdi = (0,2 + budgeti/totalbudget) · numP articipants + numP endingP roposals
        uint threshold = (0,2 + _proposals[proposalId].budget/totalBudget) * _numberOfParticipants + getPendingProposals().length;
        if (votes >= threshold && totalBudget >= _proposals[proposalId].budget) {
            _proposals[proposalId].proposal.executeProposal{value:_proposals[proposalId].budget * tokenPrice, gas: 100000}(proposalId, votes, _proposals[proposalId].budget);
            token.burn(address(this), _proposals[proposalId].budget);
            totalBudget -= _proposals[proposalId].budget;
        }     
    }


    /*closeVoting(): Cierre del periodo de votaci ́on. Solo puede ejecutar esta funci ́on el usuario
    que ha creado el contrato de votaci ́on. Cuando termina el periodo de votaci ́on se deben
    realizar entre otras las siguientes tareas:
    • Las propuestas de financiaci ́on que no han podido ser aprobadas son descartadas
    y los tokens recibidos por esas propuestas es devuelto a sus propietarios.
    • Todas las propuestas de signaling son ejecutadas y los tokens recibidos mediante
    votos es devuelto a sus propietarios.
    • El presupuesto de la votaci ́on no gastado en las propuestas se transfiere al propie-
    tario del contrato de votaci ́on.
    Cuando se cierra el proceso de votaci ́on no se deben aceptar nuevas propuestas ni votos
    y el contrato QuadraticVoting debe quedarse en un estado que permita abrir un
    nuevo proceso de votaci ́on.
    Esta funci ́on puede consumir una gran cantidad de gas, tenlo en cuenta al programarla
    y durante las pruebas */

    function closeVoting() onlyOwner
    {
        //Not approved proposals are discarded
        returnFunds(getPendingProposals());
        //All signaling proposals are executed
        uint[] memory proposalsIds = getSignalingProposals();
        for (uint256 i = 0; i < proposalsIds.length; i++) {
            _proposals[proposalsIds[i]].proposal.executeProposal(proposalsIds[i], _proposals[proposalsIds[i]].voteAmount, _proposals[proposalsIds[i]].currentBudget);
        }
        returnFunds(getSignalingProposals());
        //Not invested contracts budget is transfered to owners account
        payable(owner).transfer(totalBudget);
        //isVotingOpen => False
        isVotingOpen = false;
        freeAll();
    }

    /*returnFunds(): Funcion que devuelve los fondos de una propuesta a sus votantes.*/
    function returnFunds(uint[] memory proposalsId)
    {
        for (uint proposal_i = 0; proposal_i < proposalsId.length; proposal_i++) {//Iterate through proposals
            if (!_proposals[proposalsId[proposal_i]].valid) {
                continue;
            }
            for (uint256 voter_i = 0; voter_i < array.length; voter_i++) {//Iterate through voters of proposal_i
                address payable voter_address = _proposals[proposalsId[proposal_i]]._votersId[voter_i];//Get address of voter_i
                //Pay voter_address.n_votes^2 to voter_address
                token.transfer(voter_address, mul(_proposals[proposalsId[proposal_i]]._voters[voter_address], _proposals[proposalsId[proposal_i]]._voters[voter_address]));
            }
        }
    }

    function freeAll(){
        //TODO Clear all the arrays previosly created
    }
}