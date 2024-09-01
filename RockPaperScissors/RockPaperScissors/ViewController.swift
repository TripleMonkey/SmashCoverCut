//
//  ViewController.swift
//  RockPaperScissors
//
//  Created by Nigel Krajewski on 12/8/20.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, MCBrowserViewControllerDelegate, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {

    // MARK: Outlets and variables

    @IBOutlet weak var navItem: UINavigationItem!
    @IBOutlet weak var gameView: UIView!
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var peerChoiceImage: UIImageView!
    @IBOutlet weak var playerChoiceImage: UIImageView!
    @IBOutlet weak var winCountLabel: UILabel!
    @IBOutlet weak var loseCountLabel: UILabel!
    @IBOutlet weak var drawCountLabel: UILabel!
    @IBOutlet weak var rockButton: UIButton!
    @IBOutlet weak var paperButton: UIButton!
    @IBOutlet weak var scissorsButton: UIButton!
    @IBOutlet weak var readyButton: UIButton!

    // Timer for count down
    var countdown: Timer?
    // Int for countdown
    var playCounter = 3
    // Int for button choice tag //
    var playerChoiceTag = 1
    var peerChoiceTag = 1
    // Tuple of bools for ready status
    var readyUp = (playerOne: Bool(), playerTwo: Bool())

    // MARK: Multipeer Connection

    // Device id as seen by other devices
    var peerID: MCPeerID!
    // Device ID of connected peer
    var connectedPeer: MCPeerID!
    // Session for MC
    var session: MCSession!
    // Built-in browser VC for MC to search for advertisers
    var browser: MCBrowserViewController!
    // Advertiser to assist in presenting self to other devices
    var advertiser: MCNearbyServiceAdvertiser!

    // Browsing channel. Only devices sharing channel will see each other
    let serviceID = "rps-NK"

    // MARK: ViewDidLoad

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup MC obj values
        peerID = MCPeerID(displayName: UIDevice.current.name)
        // Use peer id for session and assign delegate
        session = MCSession(peer: peerID)
        session.delegate = self
        // Setup advertiser, assign delegate, and start advertising immediately on channel (serviceId)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceID)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        // Edit nav item text properties
        self.navigationController?.navigationBar.titleTextAttributes  = [ NSAttributedString.Key.font: UIFont(name: "Helvetica", size: 10)!]
    }

    // MARK: IBActions

    @IBAction func handleChoiceTap(_ sender: UIButton) {
        // Assign tag value
        DispatchQueue.main.async (execute: { [self] in
            playerChoiceTag = sender.tag
            // Only handle choice tap when both players are ready
            if readyUp == (true, true) {
                // Deselect any buttons already selected
                deselectButtons()
                // Set button state add icon
                sender.setBackgroundImage(UIImage(named: "buttonBackgroundColor"), for: .selected)
                sender.isSelected = true
                playerChoiceImage.image = UIImage(named: "iconChoice\(playerChoiceTag)")
                // Send choice to peer via session
                do {
                    // Convert int to data
                    let tagAsData = Data(bytes: &playerChoiceTag, count: MemoryLayout<Int>.size)
                    // Send via session
                    try session.send(tagAsData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
                }
                catch {
                    print("Error occured while sending int as data.")
                }
            }
        })
    }

    @IBAction func handleReadyTap(_ sender: UIButton) {
        // Set and send bool notification that player is ready
        DispatchQueue.main.async (execute: { [self] in
            readyUp.playerOne = true
            readyButton.isHighlighted = true
            // Encode and send bool as data
            guard let boolToData = readyUp.playerOne.description.data(using: String.Encoding.utf8)
            else { print("Conversion failed"); return }

            // Send a bool within do-catch to catch error
            do {
                try session.send(boolToData, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
            }
            catch {
                print("Error occured while sending bool as data.")
            }
            updateInstructions()
            playRound()
        })
    }

    @IBAction func handleConnectTap(_ sender: UIBarButtonItem) {
        // If not currently connected to peer
        if session.connectedPeers.count == 0
        {
            // Showe MC Browser
            showMCBrowser()
        }
        else {
            // Provide option to disconnect from current peer via alert
            let disconnectAlert = UIAlertController(title: "Search for new peer?", message: "You will be disconnected from \(peerID.displayName).", preferredStyle: .alert)
            // Crete actions
            disconnectAlert.addAction(UIAlertAction(title: "Disconnect", style: .destructive, handler: { [self] (action) in
                // Reset readyUp status
                readyUp = (false, false)
                // Disconnect from current peer
                session.disconnect()
                // Display browser to search for new peer
                showMCBrowser()
            }))
            disconnectAlert.addAction(UIAlertAction(title: "Keep playing", style: .cancel, handler: { (action) in
                // Dismiss alert
                disconnectAlert.dismiss(animated: true, completion: nil)
            }))
            // Present alert
            self.present(disconnectAlert, animated: true, completion: nil)
        }
    }

    // Show MC Browser
    func showMCBrowser() {
        // Browser will look for advertiser on same channel (serviceID)
        browser = MCBrowserViewController( serviceType: serviceID, session: session)
        // Set self (VC) as browser delegate
        browser.delegate = self
        // Show browser
        self.present(browser, animated: true, completion: nil)
    }

    // MARK: MC Browser Protocol

    // Browser protocol
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        // Dismiss presented VC
        browserViewController.dismiss(animated: true, completion: nil)
        // Update instructions based ton connection state
        self.updateInstructions()
    }

    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        // Dismiss presented VC
        browserViewController.dismiss(animated: true, completion: nil)
    }

    // Nearby service advertiser delegate call
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Alert user to request by presenting alert
        let alert = UIAlertController(title: "Incoming Connection from \(peerID.displayName)", message: "Do you want to accept the connection?", preferredStyle: .alert)
        // Crete actions
        alert.addAction(UIAlertAction(title: "Accept", style: .cancel, handler: { (action) in
            // Acceopt connection
            invitationHandler(true, self.session)
        }))
        alert.addAction(UIAlertAction(title: "Decline", style: .destructive, handler: { (action) in
            // Acceopt connection
            invitationHandler(false, self.session)
        }))
        // Present alert
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: MC delegate calls

    // Remote peer state changed notifies when connection made or ended
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Reset ready status
        readyUp = (false, false)

        // Dispatch to main for updating ui
        DispatchQueue.main.async(execute: { [self] in
            // Reset interface when connection changes
            readyButton.isEnabled = false
            readyButton.isHighlighted = false
            deselectButtons()
            updateInstructions()
            if state == MCSessionState.connected {
                connectedPeer = peerID
                navItem.title = "Connected to \(connectedPeer.displayName)."
                // Enable ready button
                readyButton.isEnabled = true
                // Dismiss browser if visable when connection made
                browser?.dismiss(animated: true, completion: nil)
            }
            else if state == MCSessionState.connecting {
                navItem.title = "Connecting..."
            }
            else if state == MCSessionState.notConnected {
                navItem.title = "Not connected."
                // Reset scoreboard when disconnected from peer
                winCountLabel.text = "0"
                loseCountLabel.text = "0"
                drawCountLabel.text = "0"
            }
        })
    }

    // Received data from remote peer
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // If data received is bool, update readyUp status
        if let stringFromData = String(data: data, encoding: String.Encoding.utf8),
           let peerReady = Bool(stringFromData) {
            DispatchQueue.main.async (execute: { [self] in
                // Update readyUp status
                readyUp.playerTwo = peerReady

                updateInstructions()
                playRound()
            })
        }
        else {
            // Convert data to int and assign to peer tag
            peerChoiceTag = data.withUnsafeBytes( {
                $0.load(as: Int.self)
            })
        }
    }

    // When receiving stream from peer
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    // When receiving resource file from peer (stared receiving)
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    // When receiving resource file from peer (finished receiving)
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    // MARK: RPS Game play

    // Function to update instructions based on player connection and ready status
    func updateInstructions() {

        if session.connectedPeers.count == 1 {
            // Switch instructions according to readyUp tuple values
            switch readyUp {
            case (false, false):
                instructionsLabel.isHidden = false
                instructionsLabel.text = "Waiting on both players to tap ready button."
            case (false, true):
                instructionsLabel.isHidden = false
                instructionsLabel.text = "\(connectedPeer.displayName) is ready.\nTap ready button to begin."
            case (true, false):
                instructionsLabel.isHidden = false
                instructionsLabel.text = "Waiting on \(connectedPeer.displayName) to tap ready button."
            case (true, true):
                // Begin gameplay count
                peerChoiceImage.image = UIImage(named: "handCount3")
                instructionsLabel.text = "Make your selection: 3"
            }
        }
        else {
            instructionsLabel.text = "Connect with a nearby player to begin."
        }
    }

    // Function to play game with timer
    func playRound() {
        // Run timer when both players are ready
        if readyUp == (true, true) {
            toggleChoiceInteraction()
            // Instaniate timer for game play
            countdown = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(roundCount), userInfo: nil, repeats: true)
            // Update score
            _ = Timer.scheduledTimer(timeInterval: 4, target: self, selector: #selector(handleRoundEnd), userInfo: nil, repeats: false)
            // Reset round after displaying results
            _ = Timer.scheduledTimer(timeInterval: 8, target: self, selector: #selector(resetRound), userInfo: nil, repeats: false)
        }
        else {
            updateInstructions()
        }
    }

    // Counter for round
    @objc func roundCount() {
        // Update instructions with countdown
        instructionsLabel.text = "Make your selection: \(playCounter.description)"
        peerChoiceImage.image = UIImage(named: "handCount\(playCounter)")
        playCounter -= 1
        if playCounter == 0 {
            // Invalidate and reset timer to nil
            toggleChoiceInteraction()
            countdown?.invalidate()
            countdown = nil
        }
    }

    // fuction to update score
    @objc func handleRoundEnd() {
        // Show peer choice
        peerChoiceImage.image = UIImage(named: "iconChoice\(peerChoiceTag)")
        // Compare results
        if playCounter == 0 {
            let results = (playerChoiceTag, peerChoiceTag)
            switch results {
            case (1,2), (2,3), (3,1):
                updateCount(forLabel: loseCountLabel)
                instructionsLabel.text = "You lost! Better luck next time."
            case (2,1), (3,2), (1,3):
                updateCount(forLabel: winCountLabel)
                instructionsLabel.text = "You won! Nice work!"
            case (1,1), (2,2), (3,3):
                updateCount(forLabel: drawCountLabel)
                instructionsLabel.text = "It's a tie. Great minds think alike!"
            default:
                return
            }
            // If choice nil i.e. player did not make selection, populate image with last choice
            if playerChoiceImage.image == nil {
                playerChoiceImage.image = UIImage(named: "iconChoice\(playerChoiceTag)")
            }
        }
    }

    // Function to reset round
    @objc func resetRound() {
        if playCounter == 0 {
            deselectButtons()
            peerChoiceImage.image = UIImage(named: "handChoice2")
            playerChoiceImage.image = nil
            readyButton.isEnabled = true
            readyUp = (false, false)
            playCounter = 3
            readyButton.isHighlighted = false
            updateInstructions()
        }
    }

    // Function to update score count
    func updateCount(forLabel: UILabel) {
        guard let  newCount = Int(forLabel.text!) else { return }
        forLabel.text = String(newCount + 1)
    }

    // Function to deselect choice buttons
    func deselectButtons() {
        rockButton.isSelected = false
        paperButton.isSelected = false
        scissorsButton.isSelected = false
    }

    // Function to toggle choice button interactivity
    func toggleChoiceInteraction() {
        rockButton.isEnabled.toggle()
        paperButton.isEnabled.toggle()
        scissorsButton.isEnabled.toggle()
    }
}

