# Student Budget Tracker / Budget Tracker

A new Flutter project to help students track their daily expenses, or for your personal use.

This is an app developed **for fun**, learning, and showcasing Flutter development skills, particularly with Firebase as a backend.

## ✨ Features

-   **User Authentication:** Secure login/registration using Firebase Authentication (Email/Password).
-   **Expense Tracking:** Add, view, and manage daily expenses.
-   **Categorization:** Organize expenses by category.
-   **Data Persistence:** Expense data is stored securely in Firebase Firestore.
-   **Cross-Platform:** Built with Flutter for Android, iOS, Web, and Desktop support.



## 📊 Latest Updates

I've recently enhanced the app with the following key features:

### Monthly Budget Planning

Users can now input their own **budget for a month**. A visual **bar chart** or **progress bar** (depending on implementation detail) visually indicates how much their expenses are affecting their current budget for that category within that specific month. This provides an immediate, clear overview of spending against planned budgets.

### Dynamic Custom Expenses

To offer greater flexibility, users can now add their **own custom expense types** for each category. This means you're no longer limited to predefined expense items but can tailor your spending descriptions to fit your specific needs, making expense tracking more personalized and accurate.

---




## 🚀 Getting Started

To run this project locally and connect it to your own Firebase backend, follow these steps:

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
* [Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli) installed.
* A Google account to create a Firebase project.

### Setup Steps

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Yamiteeee/student_budget_tracker.git](https://github.com/Yamiteeee/student_budget_tracker.git)
    cd student_budget_tracker
    ```

2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Create your Firebase Project:**
    * Go to the [Firebase Console](https://console.firebase.google.com/).
    * Click "Add project" and follow the prompts to create a new project. You can name it anything you like (e.g., `my-budget-tracker-dev`).
    * **Enable Firestore:** In your new Firebase project, navigate to "Build" > "Firestore Database" and create a database. Choose "Start in production mode" and select a region (e.g., `nam5` or one close to you).
    * **Enable Authentication:** In your new Firebase project, navigate to "Build" > "Authentication" > "Get started". Enable the "Email/Password" sign-in method under the "Sign-in method" tab.

4.  **Register your apps with Firebase & Get Config Files:**

    * **For Android:**
        * In your Firebase project settings (click the gear icon next to "Project overview"), click the Android icon (<img src="https://img.icons8.com/color/48/000000/android-os.png" width="16" height="16"/>) to add an Android app.
        * **Android package name:** `com.example.student_budget_tracker` (you can find this in `android/app/src/main/AndroidManifest.xml`)
        * (Optional but recommended for release builds): Add your SHA-1 debug certificate fingerprint.
        * Follow the instructions to **download the `google-services.json` file**.
        * Place this downloaded file into the `android/app/` directory of your Flutter project.

    * **For iOS (if applicable):**
        * In your Firebase project settings, click the iOS icon (<img src="https://img.icons8.com/color/48/000000/ios.png" width="16" height="16"/>) to add an iOS app.
        * **iOS bundle ID:** `com.example.studentBudgetTracker` (you can find this in `ios/Runner/Info.plist`)
        * Follow the instructions to **download the `GoogleService-Info.plist` file**.
        * Place this downloaded file into the `ios/Runner/` directory of your Flutter project.

    * **For Web (if applicable):**
        * In your Firebase project settings, click the Web icon (<img src="https://img.icons8.com/color/48/000000/google-chrome.png" width="16" height="16"/>) to add a Web app.
        * Follow the instructions to get the Firebase SDK configuration snippet. You'll need this for the next step.

5.  **Configure FlutterFire:**
    * Open your terminal in the root of your Flutter project and run the Firebase CLI command:
        ```bash
        flutterfire configure
        ```
    * Follow the prompts. Select your newly created Firebase project.
    * It will ask you to select platforms to configure (Android, iOS, web, macOS, Linux, Windows). Choose the ones you added in the Firebase Console (at minimum, Android).
    * This command will automatically generate the `lib/firebase_options.dart` file based on your `google-services.json`, `GoogleService-Info.plist` (if present), and any web configuration you provided.

6.  **Set up Firestore Security Rules:**
    * Go back to your Firebase Console for your project.
    * Navigate to "Build" > "Firestore Database" > "Rules".
    * Replace the default rules with the following to ensure data security and user isolation:

    ```firestore
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        // Allow read/write for authenticated users within their own user-specific path
        // Make sure your Flutter app stores data under this path:
        // /artifacts/{YOUR_APP_ID}/users/{authenticated_user_id}/{your_data_here}
        // Example: /artifacts/myBudgetTrackerApp/users/user123/expenses/expenseId
        match /artifacts/{appId}/users/{userId}/{document=**} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }

        // OPTIONAL: If you have any public collections (not user-specific)
        // For example, if you wanted a shared 'categories' collection accessible by all
        // match /publicCategories/{categoryId} {
        //   allow read: if true; // Everyone can read
        //   allow write: if request.auth != null; // Only authenticated users can write
        // }
      }
    }
    ```
    * **Important:** Verify that your Flutter application code (e.g., in your data service or repository) saves and retrieves data under the `artifacts/{appId}/users/{userId}/...` path to ensure these rules apply correctly. If your app uses a different top-level collection for user-specific data, adjust the `match` rule accordingly.
    * Click "Publish" to apply the rules.

7.  **Run the App:**
    ```bash
    flutter run
    ```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
