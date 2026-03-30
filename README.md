# Smart Fitness Pod

**Smart Fitness Pod** is a cross‑platform workout tracking application that connects to a wearable sensor via BLE. It captures real‑time accelerometer and gyroscope data, uses a deep learning model to recognise exercise types, automatically counts repetitions, records training sessions, and provides statistics and data export.

---

## Features

- **Bluetooth Device Connection**  
  Scan for and connect to `MyFitnessPod` or other BLE devices. Receive 6‑axis sensor data (acceleration + gyroscope).

- **Real‑time Exercise Recognition & Counting**  
  A TFLite model (MiniResNet) classifies movements in real time: squat, bicep curl, bench press, running. Dedicated counters count repetitions or distance.

- **Workout History**  
  Each session is automatically saved when the device disconnects. Workouts are grouped by date and can be viewed in detail (sets × reps).

- **Statistics**  
  Bar charts show daily totals for each exercise (repetitions or distance), helping users track progress over time.

- **Multi‑language Support**  
  Built‑in support for English, Simplified Chinese, Traditional Chinese, and French. The interface can be switched at runtime.

- **Data Export**  
  Raw sensor data is automatically saved as a CSV file (in the device’s download folder) for further analysis.

- **History Management**  
  All workout history can be cleared with a confirmation dialog to prevent accidental deletion.

---

## Main Project Structure
```plain
smart_fitness_pod/
├── assets/
│   ├── images/                # UI images
│   └── models/                # TFLite model (miniresnet_model.tflite)
├── i18n/                      # Localisation JSON files
│   ├── app_en.json
│   ├── app_fr.json
│   ├── app_zh.json
│   └── app_zh_TW.json
├── lib/
│   ├── i18n/                  # Localisation classes
│   │   └── app_localizations.dart
│   ├── providers/             # State management
│   │   ├── history_provider.dart
│   │   └── LocaleProvider.dart
│   ├── ui/
│   │   ├── screen/            # UI screens
│   │   │   ├── entrance_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── home_tab.dart
│   │   │   ├── history_tab.dart
│   │   │   └── settings_tab.dart
│   │   └── theme/             # App theme
│   │       └── app_theme.dart
│   ├── utils/                 # Utility classes & counters
│   │   ├── bench_press_count.dart
│   │   ├── bicepcurl_counter.dart
│   │   ├── data_preprocessing.dart
│   │   ├── test_running_count.dart
│   │   ├── test_squat_count.dart
│   │   └── utils.dart
│   └── main.dart              # App entry point
├── test/                      # Unit and widget tests
│   ├── helpers/
│   ├── mocks/
│   ├── providers/
│   ├── ui/
│   ├── utils/
│   └── widget_test.dart
├── test_driver/               # Integration test driver
│   └── app_test.dart
└── pubspec.yaml               # Dependencies
```
---

## Key Components

### 1. Bluetooth Communication (`home_tab.dart`)
- Uses `flutter_blue_plus` for scanning, connecting, and subscribing to sensor data.
- After connection, requests MTU 512 and high connection priority to optimise data transfer.
- Parses incoming data packets: first byte = number of samples in the packet, followed by 24 bytes per sample (six floats, little‑endian).

### 2. Sensor Data Processing
- Raw data (accel X/Y/Z, gyro X/Y/Z) is received in real time.
- A `_ButterworthFilter` applies low‑pass filtering to remove high‑frequency noise.
- A sliding window of the last 208 samples is maintained for model inference.

### 3. Exercise Recognition & Counting
- **TFLite Model**: `miniresnet_model.tflite` expects input shape `[1, 208, 6]` and outputs probabilities for 5 classes: `rest`, `squat`, `bicep`, `bench`, `run`.
- **Confidence threshold**: 0.7. An exercise is confirmed only after 5 consecutive high‑confidence detections.
- **Specialised Counters**:
  - **Squat**: Z‑axis peak/valley detection (peak < 7.5, valley > 6.0).
  - **Bicep curl**: Z‑axis (peak < -3.0, valley > -1.5).
  - **Bench press**: Z‑axis descent < -1.5, ascent > 0.3.
  - **Running**: X‑axis swing peak > 0.8, valley < -0.5; each full swing counts as 1.6 metres.

### 4. Data Storage
- `path_provider` is used to locate the storage directory (on Android, typically `/storage/emulated/0/Download`).
- Sensor data is written to a CSV file every 5 seconds and finalised when the device disconnects.
- Workout history is managed by `HistoryProvider`. Each `WorkoutSession` contains a list of `ExerciseSet` (exercise name, reps, sets). Sessions are merged by date and grouped by exercise name and reps.

### 5. User Interface
- Bottom navigation bar with three tabs: Home, History, Settings.
- **Home tab**: Displays the current connection state. When connected, it shows “Identifying…” or the recognised exercise with its image and a disconnect button.
- **History tab**: Lists workout sessions by date. Tapping a date opens a detailed view with sets and reps per exercise.
- **Statistics tab**: Shows a bar chart for each exercise, displaying the total repetitions (or distance) per day.
- **Settings tab**: Allows language switching and clearing of history.

### 6. Internationalisation
- `AppLocalizations` loads the appropriate JSON file based on the current locale.
- Supported locales: `en`, `zh`, `zh_TW`, `fr`.
- The app can switch languages at runtime.

---

## Technology Stack

| Category        | Technologies                                         |
|-----------------|------------------------------------------------------|
| Framework       | Flutter (≥3.0.0)                                     |
| State Management| Provider                                             |
| Bluetooth       | flutter_blue_plus                                    |
| Machine Learning| tflite_flutter                                       |
| Charts          | fl_chart                                             |
| File I/O        | path_provider, csv, permission_handler               |
| Testing         | flutter_test, flutter_driver                         |

---

## Usage

### Prerequisites
- Flutter SDK 3.0 or later.
- Android or iOS device with BLE support.
- A compatible BLE device (e.g., MyFitnessPod) that sends 6‑axis data in the expected format.

### Running the App
1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Place the model file `miniresnet_model.tflite` in `assets/models/`.
4. Place all images in `assets/images/`.
5. Connect a physical device and run `flutter run`.

### Bluetooth Connection Flow
1. On the Home tab, tap the central area to start scanning.
2. Select `MyFitnessPod` (or another device) and tap “Connect”.
3. Once connected, the app subscribes to sensor data and starts recognising exercises.
4. When an exercise is recognised, the corresponding image appears and repetitions are counted.
5. After the exercise ends, a summary screen shows the count for 2 seconds, then returns to the waiting state.
6. Tap “Disconnect” to save the current session and show a confirmation message.

### Viewing History
- Go to the History tab and tap the “Record” card.
- You will see a list of dates with workout summaries.
- Tap a date to see the detailed sets and repetitions for each exercise performed that day.

### Statistics
- In the History tab, tap the “Statistic” card.
- Select an exercise to see a bar chart of daily totals.

### Changing Language
- Open the Settings tab and tap “Language”.
- Choose your preferred language from the list. The interface updates immediately.

### Clearing History
- In Settings, tap “Clean History” and confirm. All workout data will be permanently deleted.

---

## Testing

The project includes unit tests and widget tests covering:

- **HistoryProvider**: adding sessions, merging same exercises, grouping by date, clearing.
- **LocaleProvider**: switching locales, rejecting unsupported locales.
- **Counters**: bicep curl, bench press, running counter logic.
- **UI components**: history tab, settings tab, entrance screen.
- **Integration tests**: `test_driver/app_test.dart` is set up for Flutter Driver.

Run all tests with:
```bash
flutter test
```

## Development Notes

1. **Permissions**  
   On Android, you need to declare Bluetooth and location permissions (and storage permission for CSV export). On iOS, you must add a usage description for Bluetooth in `Info.plist`.

2. **TFLite Model**  
   The model expects 208 time steps of 6 features (raw accelerometer + gyroscope). If you replace the model, adjust `_windowSize` and `_labels` accordingly.

3. **Data Packet Format**  
   The connected BLE device must send packets in the following format:  
   - 1 byte: number of samples in this packet (`n`)  
   - For each sample: 6 floats (little‑endian, 4 bytes each) → total 24 bytes per sample.  
   The app parses this format; any deviation will cause parsing errors.

4. **Counter Thresholds**  
   The thresholds used (e.g., `peakThreshold = 7.5` for squat) are calibrated based on data from a specific device. You may need to adjust them for different sensors.

5. **Performance**  
   Filtering and inference run on the UI thread. For low‑end devices, consider moving inference to an isolate. The current implementation is kept lightweight.
