enum PracticeState {
  idle, // Initial state, ready to start
  countIn, // 4-beat count-in playing
  recording, // Active recording (60s)
  processing, // Analyzing audio + generating coaching
  completed, // Session finished, ready to view results
  error, // Error occurred during session
}
