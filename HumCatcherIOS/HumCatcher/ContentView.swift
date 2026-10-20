import SwiftUI

struct ContentView: View {
    @StateObject private var detector = HumDetector()
    @AppStorage("triggerSeconds") private var triggerSeconds = 3.0
    @AppStorage("sensitivity") private var sensitivity = 4.0
    @AppStorage("decayRate") private var decayRate = 1.0

    private let accent = Color(red: 0.31, green: 0.66, blue: 0.55)
    private let alarmColor = Color(red: 0.88, green: 0.41, blue: 0.30)

    var body: some View {
        ZStack {
            (detector.alarming ? alarmColor : Color(red: 0.08, green: 0.10, blue: 0.12))
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Text("Hum Catcher")
                    .font(.title2.bold())

                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: min(1, detector.humSeconds / max(triggerSeconds, 0.1)))
                        .stroke(detector.alarming ? .white : accent,
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", detector.humSeconds))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(detector.statusText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 220, height: 220)

                ProgressView(value: detector.level)
                    .tint(detector.hearing ? accent : .gray)
                    .frame(width: 220)
                Text(detector.hearing ? "hearing you" : (detector.listening ? "quiet" : "mic off"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    if detector.alarming { detector.stopAlarm() }
                    else if detector.listening { detector.stop() }
                    else { apply(); detector.start() }
                } label: {
                    Text(detector.alarming ? "Stop alarm"
                         : detector.listening ? "Pause" : "Start listening")
                        .font(.headline)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(detector.alarming ? .white : accent)
                .foregroundStyle(detector.alarming ? alarmColor : .black)

                Text("Caught today  \(detector.caughtToday)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !detector.alarming {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Trigger after")
                            Spacer()
                            Text(String(format: "%.1f s", triggerSeconds)).monospacedDigit()
                        }.font(.footnote).foregroundStyle(.secondary)
                        Slider(value: $triggerSeconds, in: 1...10, step: 0.5)
                            .tint(accent)
                            .onChange(of: triggerSeconds) { apply() }
                        HStack {
                            Text("Decay speed")
                            Spacer()
                            Text(String(format: "%.1f×", decayRate)).monospacedDigit()
                        }.font(.footnote).foregroundStyle(.secondary)
                        Slider(value: $decayRate, in: 0...3, step: 0.5)
                            .tint(accent)
                            .onChange(of: decayRate) { apply() }
                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text(["", "very low", "low", "medium", "high", "very high"][Int(sensitivity)])
                        }.font(.footnote).foregroundStyle(.secondary)
                        Slider(value: $sensitivity, in: 1...5, step: 1)
                            .tint(accent)
                            .onChange(of: sensitivity) { apply() }
                        Text("Runs in the background — lock the phone or switch apps and it keeps listening (orange mic dot stays on).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding()
            .foregroundStyle(.white)
        }
        .onAppear { apply() }
        .preferredColorScheme(.dark)
    }

    private func apply() {
        detector.triggerSeconds = triggerSeconds
        detector.sensitivity = Int(sensitivity)
        detector.decayRate = decayRate
    }
}
