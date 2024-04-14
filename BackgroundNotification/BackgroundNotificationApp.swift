import SwiftUI
import UserNotifications
import AVFoundation

@main
struct MyApp: App {
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
        }
    }
}

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    var soundTimer: Timer?
    
    @Published var showAlert: Bool = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in }
        setupAudioSession()
        scheduleNotifications()
    }
    
    func scheduleNotifications() {
        let currentTime = Date()
        let times = [currentTime.addingTimeInterval(5)]
        for time in times {
            scheduleAlertAt(time: time)
        }
    }
    
    func scheduleAlertAt(time: Date) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time), repeats: false)
        let content = UNMutableNotificationContent()
        content.title = "It's time!"
        content.body = "Let's move a little"
        content.sound = UNNotificationSound.ringtoneSoundNamed(UNNotificationSoundName(rawValue: "alert_low.wav"))
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error as NSError {
            print("Failed to set the audio session category and mode: \(error.localizedDescription)")
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        playShortSound()
        soundTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(playLongSound), userInfo: nil, repeats: true)
        completionHandler([.banner, .sound])
    }
    
    func playShortSound() {
        guard let url = Bundle.main.url(forResource: "alert_low", withExtension: "wav") else { return }
        var sound: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        AudioServicesPlaySystemSound(sound)
        showAlert = true
    }
    
    @objc func playLongSound() {
        guard UIApplication.shared.applicationState != .active else {
            soundTimer?.invalidate()
            return
        }
        guard let url = Bundle.main.url(forResource: "alert_med", withExtension: "mp3") else {
            print("no url")
            return
        }
        var sound: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        AudioServicesPlaySystemSound(sound)
    }
    
    func onAppear() {
        print("remove timer")
        UIApplication.shared.applicationIconBadgeNumber = 0
        soundTimer?.invalidate()
    }
}

struct ContentView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack {
            Text("Background Task Example")
                .alert(isPresented: $notificationManager.showAlert) {
                    Alert(
                        title: Text("Exercise Time"),
                        message: Text("Do you want to start exercise or postpone it?"),
                        primaryButton: .default(
                            Text("Start Exercise"),
                            action: {
                                print("do exercise")
                            }
                        ),
                        secondaryButton: .default(
                            Text("Postpone 30 minutes"),
                            action: {
                                print("posponed 30 minutes")
                                self.notificationManager.scheduleAlertAt(time: Date().addingTimeInterval(1 * 60))
                            }
                        )
                    )
                }
        }
        .onAppear {
            notificationManager.onAppear()
        }
    }
}
