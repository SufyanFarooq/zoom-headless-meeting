# Next Commands to Run

## ✅ Step 1: Build the Docker Image
Yeh command Docker image build karega. Ye thoda time lega (10-15 minutes) kyunki dependencies download hongi.

```bash
docker compose build
```

## ✅ Step 2: Run the Application
Build complete hone ke baad, application run karein:

```bash
docker compose up
```

## 📋 Alternative: Build and Run in One Command
Agar aap ek hi command mein build aur run karna chahte hain:

```bash
docker compose up --build
```

## 🔍 View Logs
Application ke logs dekhne ke liye:

```bash
docker compose logs -f
```

## 🛑 Stop the Application
Application stop karna ho to:

```bash
docker compose down
```

## 📝 Notes
- Pehli baar build karte waqt thoda time lagega
- Build ke dauran koi error aaye to logs check karein
- Application successfully start hone ke baad meeting join ho jayegi

