"""App-only Simulator capture experiment. macOS stdlib and Xcode tools only."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import select
import shutil
import struct
import subprocess
import time
import uuid

root = Path(os.environ["RUNNER_TEMP"]) / "direct-overview"
root.mkdir(parents=True, exist_ok=True)
phases = []
started = None
capture_started = None
simulator = None
for old_image in root.glob("*.png"):
    old_image.unlink()
(root / "capture.json").unlink(missing_ok=True)


def run(name, arguments, *, timeout=300, environment=None):
    row = {"phase": name, "started_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
    phases.append(row)
    start = time.monotonic()
    try:
        result = subprocess.run(
            arguments, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=timeout, env=environment,
        )
        (root / f"{name}.log").write_text(result.stdout)
        row["exit_code"] = result.returncode
        print(result.stdout, end="", flush=True)
        result.check_returncode()
        return result.stdout
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        (root / f"{name}.log").write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
        row["error"] = "timeout"
        raise
    finally:
        row["seconds"] = round(time.monotonic() - start, 3)
        print(json.dumps(row), flush=True)


def assert_running(pid):
    # Simulator application PIDs are host processes. A stable SpringBoard is not success.
    os.kill(pid, 0)


def png_image(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("Simulator did not produce a PNG")
    position, payload, size = 8, bytearray(), None
    while position + 12 <= len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        chunk = data[position + 8:position + 8 + length]
        if len(chunk) != length:
            raise RuntimeError("Truncated PNG")
        if kind == b"IHDR":
            size = struct.unpack(">II", chunk[:8])
        if kind == b"IDAT":
            payload.extend(chunk)
        position += length + 12
    if not size or min(size) <= 0 or not payload:
        raise RuntimeError("PNG has no image data")
    # Ignore metadata; compare compressed image data and dimensions across consecutive frames.
    return size, hashlib.sha256(payload).hexdigest()


try:
    environment = {
        "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "xcode": subprocess.check_output(["xcodebuild", "-version"], text=True).strip(),
        "sdk": subprocess.check_output(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-build-version"], text=True).strip(),
        "fixture": "smart-start", "screenshots": 1, "compiler_cache": False,
    }
    (root / "environment.json").write_text(json.dumps(environment, indent=2) + "\n")
    if (root / "DerivedData").exists():
        shutil.rmtree(root / "DerivedData")
    started = time.monotonic()
    run("build", [
        "xcodebuild", "-project", "KASANE.xcodeproj", "-scheme", "KASANE",
        "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
        "-derivedDataPath", str(root / "DerivedData"), "-configuration", "Debug",
        "ARCHS=arm64", "ONLY_ACTIVE_ARCH=YES", "CODE_SIGNING_ALLOWED=NO",
        "COMPILATION_CACHE_ENABLE_CACHING=NO", "-showBuildTimingSummary", "build",
    ], timeout=1200)
    devices = json.loads(run("devices", ["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
    candidates = [
        device for name in ("iPhone 18 Pro Max", "iPhone 17 Pro Max")
        for runtime in sorted(devices, reverse=True) if "iOS-27" in runtime
        for device in devices[runtime] if device["isAvailable"] and device["name"] == name
    ]
    requested = os.environ.get("DIRECT_SCREENSHOT_SIMULATOR")
    device = next((item for item in candidates if not requested or item["udid"] == requested), None)
    if device is None:
        raise RuntimeError("No matching iOS 27 Pro Max simulator")
    simulator = device["udid"]
    if device["state"] == "Shutdown":
        run("boot", ["xcrun", "simctl", "boot", simulator])
    elif device["state"] != "Booted":
        raise RuntimeError(f"Unexpected Simulator state: {device['state']}")
    run("bootstatus", ["xcrun", "simctl", "bootstatus", simulator, "-b"], timeout=450)
    run("status-bar", [
        "xcrun", "simctl", "status_bar", simulator, "override", "--time", "9:41",
        "--dataNetwork", "wifi", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100",
    ])
    app = root / "DerivedData/Build/Products/Debug-iphonesimulator/KASANE.app"
    run("install", ["xcrun", "simctl", "install", simulator, str(app)])
    container = Path(run("container", ["xcrun", "simctl", "get_app_container", simulator, "com.yu1Ro5.kasane", "data"]).strip())
    documents = container / "Documents"
    documents.mkdir(exist_ok=True)
    ready = documents / ".kasane-overview-ready"
    ready.unlink(missing_ok=True)
    token = str(uuid.uuid4())
    launch_environment = dict(os.environ, SIMCTL_CHILD_KASANE_SCREENSHOT_TOKEN=token)
    capture_started = time.monotonic()
    # Subscribe before launch, then recheck the file to avoid missing an atomic rename event.
    descriptor = os.open(documents, os.O_RDONLY)
    events = select.kqueue()
    try:
        events.control([select.kevent(
            descriptor, filter=select.KQ_FILTER_VNODE,
            flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR, fflags=select.KQ_NOTE_WRITE,
        )], 0, 0)
        launch = run("launch", [
            "xcrun", "simctl", "launch", "--terminate-running-process", simulator,
            "com.yu1Ro5.kasane", "--ui-testing", "--fixture", "smart-start",
            "--direct-overview-screenshot", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ], environment=launch_environment)
        match = re.search(r"com\.yu1Ro5\.kasane:\s*(\d+)", launch)
        if match is None:
            raise RuntimeError("simctl launch did not return an application PID")
        pid = int(match[1])
        start = time.monotonic()
        deadline = start + 60
        while True:
            assert_running(pid)
            if ready.is_file() and ready.read_text() == token:
                break
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Overview fixture/insight readiness was not signalled")
            events.control(None, 1, min(remaining, 1))
        phases.append({"phase": "content-ready-wait", "seconds": round(time.monotonic() - start, 3)})
    finally:
        events.close()
        os.close(descriptor)
    previous = None
    deadline = time.monotonic() + 45
    for attempt in range(1, 21):
        assert_running(pid)
        path = root / f"frame-{attempt}.png"
        run(f"capture-{attempt}", ["xcrun", "simctl", "io", simulator, "screenshot", "--type=png", str(path)], timeout=30)
        image = png_image(path)
        if image == previous:
            assert_running(pid)
            shutil.copyfile(path, root / "overview-dashboard.png")
            (root / "capture.json").write_text(json.dumps({
                "simulator": device["name"], "udid": simulator, "width": image[0][0], "height": image[0][1],
                "stable_frames": 2, "attempts": attempt, "fixture_token": token,
            }, indent=2) + "\n")
            break
        previous = image
        if time.monotonic() >= deadline:
            raise TimeoutError("Overview pixels did not settle")
    else:
        raise TimeoutError("Overview pixels did not settle within 20 captures")
except BaseException:
    if simulator is not None:
        try:
            diagnostic = subprocess.run([
                "xcrun", "simctl", "spawn", simulator, "log", "show", "--last", "2m",
                "--style", "compact", "--predicate", 'process == "KASANE"',
            ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
            (root / "application.log").write_text(diagnostic.stdout)
        except (OSError, subprocess.TimeoutExpired) as error:
            (root / "application-log-error.log").write_text(str(error))
    raise
finally:
    total = round(time.monotonic() - started, 3) if started is not None else None
    capture_seconds = round(time.monotonic() - capture_started, 3) if capture_started is not None else None
    (root / "timings.json").write_text(json.dumps({
        "phases": phases, "experiment_seconds": total, "launch_to_capture_seconds": capture_seconds,
        "screenshot_created": (root / "overview-dashboard.png").exists(),
    }, indent=2) + "\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write("## Direct overview screenshot prototype\n\n| Phase | Seconds |\n| --- | ---: |\n")
        for phase in phases:
            summary.write(f"| {phase['phase']} | {phase.get('seconds', 'n/a')} |\n")
        summary.write(f"| App build through PNG (wall time) | {total} |\n")
        summary.write(f"| Launch through PNG (wall time) | {capture_seconds} |\n\n")
        summary.write(f"PNG created: {(root / 'overview-dashboard.png').exists()}\n\n")
        summary.write("One overview screen, app-only uncached build, no XCTest. Readiness marker + two identical image frames; no fixed settling sleep.\n\n")
        summary.write("Wall time excludes checkout, Xcode selection and project generation. The five-screen UI Screenshot job is not a matched one-screen baseline; do not attribute its total difference entirely to this method.\n")
