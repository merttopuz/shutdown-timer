import { showHUD, showToast, Toast } from "@raycast/api";
import { errorMessage, hasTimer, isUserCancel, runScriptAsRoot } from "./lib";

export default async function Command() {
  // Do not ask for the password when there is nothing to cancel.
  if (!hasTimer()) {
    await showHUD("No active timer.");
    return;
  }

  try {
    await showToast({ style: Toast.Style.Animated, title: "Waiting for administrator password" });
    await showHUD(await runScriptAsRoot("cancel"));
  } catch (error) {
    if (isUserCancel(error)) {
      await showToast({ style: Toast.Style.Failure, title: "Cancelled", message: "The timer is still active" });
      return;
    }
    await showToast({ style: Toast.Style.Failure, title: "Could not cancel the timer", message: errorMessage(error) });
  }
}
