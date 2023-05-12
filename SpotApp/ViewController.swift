//
//  ViewController.swift
//  SpotApp
//
//  Created by Nicholas English on 10/5/22.
//

import UIKit
import CocoaMQTT
import CDJoystick
import AVFAudio



var connected = false // whether connected to mqtt host

// Create a speech synthesizer.
let synthesizer = AVSpeechSynthesizer()

// Create a speech recognizer
let speech = SpeechRecognizer()

var text = ""

var cancellable = speech.$transcript.sink(receiveValue: { newTitle in
    print("Title changed to: '\(newTitle)'")
    print("ViewModel title is: '\(speech.transcript)'")
})
//speech.transcript = "@Published explained"


// MARK: -HOME VIEW
/**
    Controller for home view.  Handles connection to server.
 */
class HomeViewController: UIViewController {
    
    // Mqtt client and host data
    struct MqttInfo {
//        static var mqttClient = CocoaMQTT(clientID: "iOS Device", host: "192.168.1.2", port: 1883) // new pi irobot
        static var mqttClient = CocoaMQTT(clientID: "iOS Device", host: "137.146.188.247", port: 1883) // new pi irobot
    }
    
    //let mqttClient = CocoaMQTT(clientID: "iOS Device", host: "137.146.127.40", port: 1883) // old pi
    //let mqttClient = CocoaMQTT(clientID: "iOS Device", host: "137.146.255.24", port: 1883) // new pi guest access
    //let mqttClient = CocoaMQTT(clientID: "iOS Device", host: "137.146.188.247", port: 1883) // new pi irobot
    let mqttClient = MqttInfo.mqttClient
    
    @IBOutlet weak var connButton: UIButton!
    
    @IBOutlet weak var connStatus: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        mqttClient.didConnectAck = {mqtt, ack in
            self.mqttClient.subscribe("rpi/mssg")
            self.mqttClient.didReceiveMessage = {mqtt, message, id in
                print("message in ", message.topic , ": ", message.string!)
            }
        }
        
        // Set initial text
        if !connected {
            startButton.isHidden = true
            connStatus.text = "Status: Disconnected"
            connButton.setTitle("Connect", for: .normal)
        } else {
            startButton.isHidden = false
            connStatus.text = "Status: Connected"
            connButton.setTitle("Disconnect", for: .normal)
        }
        
    }

    /**
        Publishes test message
     */
    @IBAction func mssgSend(_ sender: UISwitch) {
        if sender.isOn {
            mqttClient.publish("rpi/mssg", withString: "on")
        }
        else {
            mqttClient.publish("rpi/mssg", withString: "off")
        }
    }
    
    /**
        Go to controller view
     */
    @IBAction func showController(_ sender: UIButton) {
        self.performSegue(withIdentifier: "showController", sender: sender)
    }
    
    /**
        Controls connection to mqtt server
     */
    @IBAction func connectButton(_ sender: UIButton) {
        if connected { // Disconnect
            mqttClient.disconnect()
            sender.setTitle("Connect", for: .normal)
            connected = false
            connStatus.text = "Status: Disconnected"
            startButton.isHidden = true
        } else { // Connect
            connected = mqttClient.connect()
            print(connected)
            if connected {
                sender.setTitle("Disconnect", for: .normal)
                connStatus.text = "Status: Connected"
                startButton.isHidden = false
            } else {
                print("Connection failed")
            }
        }
    }
    
    /**
     Disconnect from MQTT
     */
    @IBAction func disconnectButton(_ sender: UIButton) {
        mqttClient.disconnect()
    }
    
    
    
}



//class SharingManager {
//    static let sharedInstance = SharingManager()
//    var updateLabel: (() -> Void)?
//    var labelChange: String = text {
//        didSet {
//            print("set")
//            updateLabel?()
//        }
//    }
//
//}



// MARK: -CONTROLLER VIEW
/**
    Controls the controller screen.  Handles joystick input, launch and shutdown,
 */
class ControllerViewController: UIViewController {
    
    let mqttClient = HomeViewController.MqttInfo.mqttClient
    
    // config vars
    private let scale: CGFloat = 5.0
    var angle: CGFloat = 0.0
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0
    var launched = false
    var speed = 0.5
    var cmd = 0.5
    
    // track movement for careful send
    var movestack = 0
    var movetime: DispatchTime? = nil
    
    var MODE = true
    var isTranscribing = false
    
    
    
    @IBOutlet weak var voiceComm: UIButton!
    @IBOutlet weak var round: UIImageView!
    @IBOutlet weak var transcript: UILabel!
    
    @IBOutlet weak var ModeSwitch: UIButton!
    
    @IBOutlet weak var toolbar: UIToolbar!
    
    @IBOutlet weak var movJoy: CDJoystick!
    @IBOutlet weak var rotJoy: CDJoystick!
    
    @IBOutlet weak var movlab: UILabel!
    @IBOutlet weak var rotlab: UILabel!
    
    // center menu stacks
    @IBOutlet weak var settingsMenu: UIStackView!
    @IBOutlet weak var manipMenu: UIStackView!
    @IBOutlet weak var rollMenu: UIStackView!
    @IBOutlet weak var missionMenu: UIStackView!
    
    @IBOutlet weak var stand: UIButton!
    @IBOutlet weak var sit: UIButton!
    
    // launch / shutdown button
    @IBOutlet weak var startStop: UIButton!
    
    // joysticks
    @IBOutlet private weak var joystickRotate: CDJoystick!
    @IBOutlet private weak var joystickMove: CDJoystick!

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        AVSpeechSynthesisVoice.speechVoices()
//        SharingManager.sharedInstance.updateLabel = updateTranscript
        
        joystickMove.trackingHandler = { joystickData in
            // print("joystickMove data: \(joystickData)")
            
            self.x = self.clamp(joystickData.velocity.x * self.scale, lower: -10, upper: 10)
            self.y = self.clamp(joystickData.velocity.y * self.scale, lower: -10, upper: 10)
            
            self.handleBasics(x: self.x, y: self.y)
        }
        
        joystickRotate.trackingHandler = { joystickData in
            //print("joystickRotate data: \(joystickData)")
            
            self.angle = joystickData.angle
            self.handleBasics(radians: self.angle, rotVel: joystickData.velocity)
            //print(self.angle)
        }
        
        mqttClient.didConnectAck = {mqtt, ack in
            self.mqttClient.subscribe("rpi/directControl")
            self.mqttClient.didReceiveMessage = {mqtt, message, id in
                print("message in ", message.topic , ": ", message.string!)
            }
        }
        
        speech.reset()
        
        settingsMenu.isHidden = true
        ModeSwitch.setTitle("Voice Interface", for: .normal)
        voiceComm.isHidden = true
        round.isHidden = true
        transcript.isHidden = true
        
        self.speak(text: "Starting Controls")
        
        cancellable = speech.$transcript.sink(receiveValue: { [weak self] value in
//                print("transcript changed to \(value)")
                text = value
                self?.updateTranscript()
            })
        updateTranscript()
    }
    
    
    
    
    func updateTranscript(){
        transcript.text = speech.transcript
//        print("Transcript label text is now: '\(transcript.text ?? "empty")'")
    }
    
    /**
     Executes additional actions when back button is pressed.
     */
    @IBAction func back(_ sender: Any) {
        self.speak(text: "Back")    // speak
    }
    
    // MARK: -Speech & VI
    /**
     Creates and executes an utterance to speak input text.
     
     - Parameter text: the str to speak
     */
    func speak(text: String) {
        // Create an utterance.
        let utterance = AVSpeechUtterance(string: text)

        // Configure the utterance.
        utterance.rate = 0.57
        utterance.pitchMultiplier = 0.8
        utterance.postUtteranceDelay = 0.2
//        utterance.volume = 1.0

        // Retrieve the British English voice.
        let voice = AVSpeechSynthesisVoice(language: "en-GB")

        // Assign the voice to the utterance.
        utterance.voice = voice

        // Tell the synthesizer to speak the utterance.
        synthesizer.speak(utterance)
        
        
        do{
            let _ = try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback,
                                                                    options: .duckOthers)
          }catch{
              print(error)
          }
    }
    
    
    /**
     Switches between physical and voice interface modes.  Hides components accordingly.  Speaks transition.
     */
    @IBAction func switchMode(_ sender: Any) {
        if MODE { // to voice interface
            ModeSwitch.setTitle("Physical Interface", for: .normal)
            settingsMenu.isHidden = true
            manipMenu.isHidden = true
            rollMenu.isHidden = true
            missionMenu.isHidden = true
            startStop.isHidden = true
            toolbar.isHidden = true
            movJoy.isHidden = true
            rotJoy.isHidden = true
            movlab.isHidden = true
            rotlab.isHidden = true
            stand.isHidden = true
            sit.isHidden = true
            voiceComm.isHidden = false
            round.isHidden = false
            transcript.isHidden = false
            self.speak(text: "Voice Interface")
        } else { // to physical interface
            ModeSwitch.setTitle("Voice Interface", for: .normal)
            toolbar.isHidden = false
            startStop.isHidden = false
            movJoy.isHidden = false
            rotJoy.isHidden = false
            movlab.isHidden = false
            rotlab.isHidden = false
            stand.isHidden = false
            sit.isHidden = false
            voiceComm.isHidden = true
            round.isHidden = true
            transcript.isHidden = true
            self.speak(text: "Physical Interface")
        }
        MODE = !MODE
    }
    
    /**
     Starts or stops transcription.  If stopping, sends the transcript to the handler for processing.
     */
    @IBAction func toggleTranscribe(_ sender: Any) {
        if isTranscribing { // stop transcribing, handle the transcript
//            speech.transcript = speech.transcript
//            text = speech.transcript
//            transcript.text = speech.transcript
//            self.speak(text: speech.transcript)
//            print("stop",speech.transcript)
            self.handleSpeech(text: speech.transcript)
            speech.reset()
        } else { // start transcribing
            speech.transcribe()
//            print("start")
        }
        isTranscribing = !isTranscribing
    }
    
    /**
     Handles processing commands from speech transcripts.  Calls send with any commands found.
     
     - Parameter text: string containing potential command
     */
    private func handleSpeech(text:String) {
        if text.count < 9 { //Safety check, too short to contain command
            return
        }
        
        if text.prefix(9) != "Hey spot " { //Not a command, return
            return
        }
        
        // Grab potential command portion from transcript
        let chars = Array(text)
        let command = String(chars[9...])
        print("command:"+command)
        self.speak(text:command)
        
        let validCommands = ["start":1, "stop":1, "sit":1, "stand":1, "shutdown":2, "off":2,
                             "speed up":1, "speed down":1, "command up":1, "command down":1]
        
        // Check against valid commands, send
        if validCommands.keys.contains(command){
            if validCommands[command] == 1 {
                self.send(message: command, priority: true)
            } else if validCommands[command] == 2 {
                self.send(message: command, emerg:true, priority: true)
            }
        } else {
            self.send(message: "commandset2.5",priority: true)
            self.send(message:command,priority: true)
            self.send(message: "commandset"+String(cmd),priority: true)
        }
        if command == "launch" || command == "start"{
            startStop.setTitle("SHUTDOWN", for: .normal)
            launched = true
        } else if command == "shutdown" {
            startStop.setTitle("LAUNCH", for: .normal)
            launched = false
        }
    }
    
    
    
    // MARK: -Launch & Estop
    /**
        Launches or shuts down Spot
     */
    @IBAction func LaunchEstop(_ sender: UIButton) {
        print("launchEstop: ", launched)
        if launched == false{ // Launch
            self.mqttClient.publish("rpi/directControl", withString: "launch")
            startStop.setTitle("SHUTDOWN", for: .normal)
            launched = true
        } else { // Shut down
            self.mqttClient.publish("rpi/directControl", withString: "shutdown")
            startStop.setTitle("LAUNCH", for: .normal)
        }
    }
    
    /**
        Sends emergency stop message, disconnects mqtt, and returns to home screen
     */
    @IBAction func Estop(_ sender: Any) {
        send(message: "estop", emerg: true) // estop Spot
        self.mqttClient.disconnect() // disconnect mqtt
        connected = false
        performSegue(withIdentifier: "contToHome", sender: sender) // go home screen
    }
    
    
    // MARK: -Submenus
    /**
     Opens the settings menu
     */
    @IBAction func Settings(_ sender: Any) {
        settingsMenu.isHidden = !settingsMenu.isHidden
        manipMenu.isHidden = true
        missionMenu.isHidden = true
        rollMenu.isHidden = true
    }
    
    /**
     Opens the manipulation menu
     */
    @IBAction func Manipulation(_ sender: Any) {
        manipMenu.isHidden = !manipMenu.isHidden
        settingsMenu.isHidden = true
        missionMenu.isHidden = true
        rollMenu.isHidden = true
    }
    
    /**
     Opens the missions menu
     */
    @IBAction func Missions(_ sender: Any) {
        missionMenu.isHidden = !missionMenu.isHidden
        settingsMenu.isHidden = true
        manipMenu.isHidden = true
        rollMenu.isHidden = true
    }
    
    /**
     Opens the roll menu
     */
    @IBAction func Roll(_ sender: Any) {
        rollMenu.isHidden = !rollMenu.isHidden
        settingsMenu.isHidden = true
        missionMenu.isHidden = true
        manipMenu.isHidden = true
    }
    
    
    // MARK: -Joysticks
    /**
     Converts raw joystick data to usable format
     
     - Parameter value: raw input
     - Parameter lower: low bound of desired output range
     - Parameter upper: upper bound of desired output range
     
     - Returns: a clamped representation of the raw data
     */
    private func clamp<T: Comparable>(_ value: T, lower: T, upper: T) -> T {
        return min(max(value, lower), upper)
    }
    
    /**
     Handles basic control functionality with input from the joysticks.
     
     - Parameter x: x component of the movement joystick
     - Parameter y: y component of the movement joystick
     - Parameter radians: radian measurement of direction from the rotation joystick
     - Parameter rotVel: velocity output of the rotation joystick (i.e., strength of force)
     */
    private func handleBasics(x: CGFloat = 0, y: CGFloat = 0, radians: CGFloat = 0, rotVel: CGPoint = CGPoint(x: 0,y: 0)){
        var mssg: [String] = []
        
        // Handle data from movement joystick
        if abs(y) > 2 {  // Handle y-axis
            if y > 0 {
                mssg.append("backwards")
            } else {
                mssg.append("forward")
            }
        }
        if abs(x) > 2 {  // Handle x-axis
            if x > 0 {
                mssg.append("right")
            } else {
                mssg.append("left")
            }
        }
        
        // Handle data from the rotation joystick
        if abs(rotVel.x) > 0.5 || abs(rotVel.y) > 0.5{  // 
            if radians > 3 {
                mssg.append("turnleft")
            } else {
                mssg.append("turnright")
            }
        }
        
        
        if mssg.count > 0{
            for i in mssg {
                carefulSend(message: i)
            }
        }
    }
    
    
    // MARK: -Setters & Toggles

    @IBAction func setHeight(_ sender: UISlider) {
        send(message: "setHeight" + String(sender.value), priority: true)
    }
    
    @IBAction func setSpeed(_ sender: UIStepper) {
        if sender.value > speed {
            send(message: "speedup", priority: true)
        } else {
            send(message: "speeddown", priority: true)
        }
        speed = sender.value
    }
    
    @IBAction func setCmdAcc(_ sender: UIStepper) {
        if sender.value > cmd {
            send(message: "commandup", priority: true)
        } else {
            send(message: "commanddown", priority: true)
        }
        cmd = sender.value
    }
    
    @IBAction func setMouth(_ sender: UISlider) {
        send(message: "setMouth" + String(sender.value), priority: true)
    }
    
    @IBAction func toggleMouth(_ sender: Any) {
        send(message: "mouth", priority: true)
    }
    
    @IBAction func selfRight(_ sender: Any) {
        send(message: "selfRight", priority: true)
    }
    
    @IBAction func batteryRoll(_ sender: Any) {
        send(message: "battRoll", priority: true)
    }
    
    
    @IBAction func sit(_ sender: Any) {
        send(message: "sit", priority: true)
    }
    
    @IBAction func stand(_ sender: Any) {
        send(message: "stand", priority: true)
    }
    
    @IBAction func stow(_ sender: Any) {
        send(message: "stow", priority: true)
    }
    
    @IBAction func unstow(_ sender: Any) {
        send(message: "unstow")
    }
    
    @IBAction func fetchTug(_ sender: Any) {
        send(message: "fetchtug")
    }
    
    @IBAction func fetchBottle(_ sender: Any) {
        send(message: "fetch")
    }
    
    
    // MARK: -Send Mssgs
    /**
        Publishes message with optional emergency send
     
        - Parameter message: string to send
        - Parameter emerg: bool, whether to emergency send current message, default false
        - Parameter priority: bool, whether message gets priority, default false
     */
    private func send(message: String, emerg: Bool = false, priority: Bool = false){
        let tmessage = message.replacingOccurrences(of: " ", with: "")
        print("sending",tmessage)
        if emerg {
            self.mqttClient.publish("rpi/emerg", withString: tmessage)
        } else if priority {
            let temp = movestack
            movestack = 0
            carefulSend(message: tmessage)
            movestack = temp
        } else {
            carefulSend(message: tmessage)
        }
    }
    
    /**
        Publishes messages carefully, allowing existing stack to finish
     
        - Parameter message: String, message to publish
     */
    private func carefulSend(message: String){
//        if movestack == 0 {
//            movetime = DispatchTime.now()
//        }
        if movestack < 3{
            self.mqttClient.publish("rpi/directControl", withString: message)
            movestack += 1
            // print("add to stack", movestack)
            movetime = DispatchTime.now()
        }
        if movetime != nil{
            if (movetime!) + 0.5 < DispatchTime.now(){
                // print("time elapsed")
                if movestack > 0{
                    movestack -= 1
                    // print("decrease stack", movestack)
                } else {
                    // print("empty stack")
                    movetime = nil
                }
            }
        }
//        if movetime != nil{
//            if (movetime!) + (0.25 * Double(movestack)) < DispatchTime.now(){
//                movestack = 0
//                movetime = nil
//            }
//        }
    }
        
        
        
    
    
    
}















