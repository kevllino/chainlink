# Network interactions for distributed key generation

This describes the network messages participants must send each other, to
construct a distributed public/secret key pair. The purpose is construction of
threshold signatures, as outlined in figure 4, p. 74 of [Secure Distributed Key
Generation for Discrete-Log Based Cryptosystems
](https://link.springer.com/content/pdf/10.1007/s00145-006-0347-3.pdf).

Note that as described in that paper, this allows an adversary a small degree of
control over the public key (through exiting the protocol early), but, as it
argues, that control is insufficent to seriously weaken the security of the
signature protocol. Just don't use it in contexts which depend on the public key
being a uniform sample!

Since in the end we can't trust the network to deliver messages for us, a key
idea for the final version of the workflow is to use a smart contract on the
blockchain itself as a coordination mechanism, because it's explicitly designed
for censorship resistance. To keep things cheap on the happy path, this trick is
only used when failures are observed.

There are some complex ideas in what follows for allowing on-chain
accountability for off-chain misbehavior in later versions. An alternative would
be for signatures to sign the desired message, plus a message describing the
participants' performances. This could be combined with the original message
just by hashing the concatenation of the hashes of the two messages. This
lengthens the signatures (you have to send the hash of the performance message
along, for verifiers who only want to verify the original message), but does
lead to a much simpler protocol.

## Intended full workflow

While this is an ordered list, many of the steps are independent, especially
between nodes. It is not necessary to synchronize the nodes at every step,
unless that's explicitly indicated.

0. **In the initial version**, we'll just ignore the smart-contract coordinator.
   In later versions the process kicks off with an event from a smart contract.
   The contract will be an early part of the development, though, if only to
   store the participants which are still in good standing so that the nodes can
   look up who to talk to.
1. <a href="node-indices"/> The index assigned to each node is its ordinal index
   in some list, such as the service agreement which the group is signing
   reports to.
2. Nodes contact each other through a DHT, looking up the other participants'
   host info via their public keys. Chainlink will run a bootstrap node for
   this DHT.
3. Every node requests the public keys of the coefficients (*Aᵢₖ=aᵢₖG*, in
   section 2.4, step 3 of [Stinson and Strobl 2001
   ](https://www.researchgate.net/profile/Willy_Susilo/publication/242499559_Information_Security_and_Privacy_13th_Australasian_Conference_ACISP_2008_Wollongong_Australia_July_7-9_2008_Proceedings/links/00b495314f3bcaaa46000000.pdf#page=426))
   of every other node.
   1. In the happy path, the nodes comply with these requests, sending the same
      public keys to every other node. In the final version of the protocol,
      these should be preceded by a signed merkle-tree commitment to the full
      set of keys, and the keys should be sent as signed batches of merkle
      subtrees, along with the merkle path to the initial commitment. 
      
      **In the initial version** assuming the happy path, the commitments can
      just be sent over as a block.
   2. Failure 1: Some node sends inconsistent coefficient-public-keys *Aᵢₖ* to
      other nodes. In the final version the nodes publish the initial
      commitments they've received from every other node, and every node
      compares them. Any inconsistencies are reported to a smart contract where
      the offending node has a stake, and it is slashed (this is the reason the
      commitments should be sent in small batches with independent signatures,
      so that on-chain verification is not too expensive.) The node is removed
      from further participation in the DKG. **In the first initial version**,
      the offending node is just removed without being slashed. 
   3. Failure 2: A node fails to send some portion of its commitments to some
      other node. Punishing this directly is more complex, because it cannot be
      cryptographically verified. It's tempting to add a financial penalty for
      consistent failure to deliver, but not strictly necessary, since the
      protocol is designed to continue if some fraction of nodes drop out.
      
      However, it will be useful for any pair of nodes with a good connection to
      be able to request a third node's data from each other, in order to route
      around partial network failures. For this purpose, the nodes can publish
      to each other which portions of the data they have received. Since the
      messages are signed, there is no scope here for intermediaries to corrupt
      the data they forward. 
      
      Obviously, that is **not needed for the initial version.**
4. All nodes *j* ask all other nodes *i* for their secret share (*fᵢ*(*j*), in
   the notation of step 1 of section 2.4 in Stinson & Strobl, where *j* is the
   [index described above](#node-indices).) Once they've verified their shares
   from a particular node, as in equation (2) in Stinson and Strobl, they
   announce to the network. In a later version, the response with the shares
   must include a merkle commitment to the calculation verifying the shares.
   (These are just sums of scalar multiples of the transmitting node's
   commitments, so they can be arranged in nice binary trees using
   associativity.) Nodes broadcast to the group who they've received correct
   shares from.
   1. If some node doesn't respond to some other node with its secret shares by
      a certain number of blocks, the recipient can post a request on the
      coordinating contract. If the mandated sender repeated fails to respond
      on-chain, they should be slashed and removed from the process. The
      on-chain response must be the shares, encrypted with the recipient's
      public key.
      
      **In the initial version**, we'll just pretend everyone responds
      faithfully.
   2. If some node sends shares which don't verify, the recipient posts a
      complaint to the contract, along with merkle commitments to the two halves
      of calculation it's done during the verification process. The defendant
      node must respond within a few blocks, stating which half differs. The
      process repeats recursively, until the leaves of the calculation are
      reached. If they involve valid multiples of the coefficient commitments
      for that part of the calculation the defendant wins and the plaintiff is
      slashed, otherwise vice versa.
      
      **In the initial version,** we'll just broadcast the complaint amongst the
      group over the network, as usual, and nodes will be responsible for
      verifying the complaint and ejecting the bad actor themselves (already
      implemented). In a later version, nodes can vote on-chain on which side of
      the complaint is correct, and the loser is slashed if the vote exceeds the
      signature threshold. In a still later version, we can do the full
      verification on-chain. We won't be able to do that for very large
      signature groups, though, so we'll need the challenge/response protocol
      described above.
5. After some timeout, if there's no clique of nodes who have reported receiving
   correct shares from each other, key generation halts. Otherwise, the maximal
   clique is used from here on, and the other participants are thrown out for
   the life of the key.
6. The remaining members all share the public keys of their secret coefficients
   (the *Aᵢₖ*=*aᵢₖG*, in step 3 of section 2.4 of Stinson and Strobl), using
   much the same protocol as in the [above three steps](#coefficient-request)
   for the coefficient commitments.
7. After some timeout, if any node has failed to fully and correctly report its
   coefficient's public keys, its secret coefficients are reconstructed by the
   remaining nodes. The failure is noted on the contract, and the failing node
   is slashed and excluded from further participation. In order for the
   reconstruction to occur, every node but the failing one broadcasts the secret
   share they received from the failure. If any node fails to receive one of
   these shares, 