//
//  ContentView.swift
//  neverstop Watch App
//
//  Created by admin on 10/24/23.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    @State private var longPressDuration = 5.0

    var longPress: some Gesture {
        LongPressGesture(minimumDuration: longPressDuration)
            .updating($isDetectingLongPress) { currentState, gestureState, transaction in
                gestureState = currentState
                transaction.animation = Animation.linear(duration: longPressDuration)
                self.completedLongPress = false;
            }
            .onEnded { finished in
                self.completedLongPress = finished
                self.workoutManager.endWorkout()
            }
    }
    var body: some View {
        GeometryReader { geometry in
            if workoutManager.authorizationGranted {
                VStack(spacing: 20) {
                    TimelineView(MetricsTimelineSchedule(from: workoutManager.builder?.startDate ?? Date(),
                                                         isPaused: workoutManager.session?.state == .paused)) { context in
                        ElapsedTimeView(elapsedTime: workoutManager.builder?.elapsedTime(at: context.date) ?? 0, showSubseconds: context.cadence == .live)
                    }
                    if workoutManager.running == false {
                        Button(action: {
                            self.completedLongPress = false
                            workoutManager.selectedWorkout = .running;
                        }) {
                            Text("Start")
                                .font(.system(size: 25))
                                .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
                                .background(Color.blue)
                                .cornerRadius(15)
                        }
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
                        .cornerRadius(15)
                    }
                    else {
                        Text("Hold to stop")
                            .font(.system(size: 25))
                            .gesture(longPress)
                            .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.5)
                            .background {
                                VStack {
                                    Rectangle()
                                        .fill(Color.red.opacity(1.0))
                                        .frame(maxWidth: isDetectingLongPress ? .infinity : 0)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(completedLongPress ? Color.red : Color.green.opacity(1.0))
                            }
                            .cornerRadius(15)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                VStack(alignment: .leading){
                    Text("⚠️ Oops! It seems some required permissions are not enabled for this app. Go to the 'Settings' app to grant access and unlock all features.")
                    
                    Spacer()
                    Button {
                        workoutManager.checkAuthorizationStatus()
                    } label: {
                        Text("Check Granted")
                    }
                    
                }
            }
        }
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WorkoutManager())
    }
}

private struct MetricsTimelineSchedule: TimelineSchedule {
    var startDate: Date
    var isPaused: Bool

    init(from startDate: Date, isPaused: Bool) {
        self.startDate = startDate
        self.isPaused = isPaused
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var baseSchedule = PeriodicTimelineSchedule(from: self.startDate,
                                                    by: (mode == .lowFrequency ? 1.0 : 1.0 / 30.0))
            .entries(from: startDate, mode: mode)
        
        return AnyIterator<Date> {
            guard !isPaused else { return nil }
            return baseSchedule.next()
        }
    }
}
