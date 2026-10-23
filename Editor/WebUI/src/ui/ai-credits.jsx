import React from "react";
import { studio } from "./state.js";
import { t, currentLanguage } from "../localization.js";
import { creditAmount } from "../ai-credits.js";

export function AICredits({ details = false }) {
  const s = studio,
    balance = s.aiBalance;
  return (
    <div className="agent-usage" aria-live="polite" data-testid="ai-credits">
      <strong>
        {balance
          ? t(
              "AI credits: {0} / {1}",
              creditAmount(balance.available),
              creditAmount(balance.allowance),
            )
          : t("AI credits —")}
      </strong>
      {details && (
        <>
          <p>
            {t(
              "Cloud Pro includes 500 AI credits per month, shared across your devices.",
            )}
          </p>
          {balance && (
            <>
              <p>
                {t(
                  "Used: {0} · Reserved: {1}",
                  creditAmount(balance.spent),
                  creditAmount(balance.reserved),
                )}
              </p>
              {balance.cycleEnd > 0 && (
                <p>
                  {t(
                    "Credits renew: {0}",
                    new Date(balance.cycleEnd * 1000).toLocaleDateString(currentLanguage()),
                  )}
                </p>
              )}
              {!balance.allowance && <a href="/cloud">{t("Get Cloud Pro")}</a>}
              {balance.allowance > 0 && balance.available === 0 && (
                <p role="status">
                  {t(
                    "Your AI credits are used up. They renew with your monthly Cloud Pro allowance.",
                  )}
                </p>
              )}
            </>
          )}
          {s.aiPhase === "unavailable" && (
            <p>{t("AI credit balance is unavailable. Please retry.")}</p>
          )}
          {s.aiCatalog && !s.aiCatalog.enabled && (
            <p>{t("Ada AI is not available on this server yet.")}</p>
          )}
          <button
            className="text-button"
            disabled={s.aiPhase === "loading"}
            onClick={() => s.refreshAI()}
          >
            {t("Refresh AI credits")}
          </button>
        </>
      )}
    </div>
  );
}
