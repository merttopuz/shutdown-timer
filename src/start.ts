import { LaunchProps, showHUD, showToast, Toast } from "@raycast/api";
import { errorMessage, isUserCancel, runScriptAsRoot } from "./lib";

const DEFAULT_MINUTES = 120;

export default async function Command(props: LaunchProps<{ arguments: Arguments.Start }>) {
  const raw = (props.arguments.minutes ?? "").trim();
  const minutes = raw === "" ? DEFAULT_MINUTES : Number(raw);

  if (!/^\d*$/.test(raw) || !Number.isInteger(minutes) || minutes < 1) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Invalid duration",
      message: "Enter a number of minutes (example: 120)",
    });
    return;
  }

  try {
    await showToast({ style: Toast.Style.Animated, title: "Waiting for administrator password" });
    const result = await runScriptAsRoot(String(minutes));
    await showHUD(result);
  } catch (error) {
    if (isUserCancel(error)) {
      await showToast({ style: Toast.Style.Failure, title: "Cancelled", message: "No timer was set" });
      return;
    }
    await showToast({ style: Toast.Style.Failure, title: "Could not start the timer", message: errorMessage(error) });
  }
}
