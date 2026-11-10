import { showHUD, showToast, Toast } from "@raycast/api";
import { errorMessage, runScript } from "./lib";

export default async function Command() {
  try {
    await showHUD(await runScript("status"));
  } catch (error) {
    await showToast({ style: Toast.Style.Failure, title: "Could not read the timer", message: errorMessage(error) });
  }
}
