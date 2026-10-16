package org.adaengine.studio;

import android.app.AlertDialog;
import android.app.NativeActivity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;
import android.database.Cursor;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.speech.RecognizerIntent;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.text.InputType;
import android.util.Base64;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.EditText;
import android.widget.FrameLayout;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.KeyStore;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Platform services for the shared Swift/AdaUI mobile application. */
public final class StudioActivity extends NativeActivity {
    private static final int DOCUMENTS = 7001, SPEECH = 7002;
    private static final int MAX_FILE_BYTES = 8 * 1024 * 1024;
    private final HashMap<Integer, Long> pending = new HashMap<>();
    private final ExecutorService files = Executors.newSingleThreadExecutor();
    private boolean foreground;
    private boolean bridgeReady;
    private View inputView;
    private AlertDialog prompt;
    private long promptRequest;
    private TextToSpeech speaker;
    private boolean speakerReady;
    private long speechRequest;
    private String speechText;
    private long authRequest;

    private static native void deliver(long request, String payload);

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        inputView = new View(this) {
            @Override public boolean onCheckIsTextEditor() { return true; }
            @Override public InputConnection onCreateInputConnection(EditorInfo info) {
                info.inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE;
                info.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_FLAG_NO_FULLSCREEN;
                return new BaseInputConnection(this, false) {
                    private String composing = "";
                    @Override public boolean commitText(CharSequence text, int position) {
                        composing = "";
                        sendText(text.toString(), false);
                        return true;
                    }
                    @Override public boolean setComposingText(CharSequence text, int position) {
                        composing = text.toString();
                        return true;
                    }
                    @Override public boolean finishComposingText() {
                        if (!composing.isEmpty()) sendText(composing, false);
                        composing = "";
                        return true;
                    }
                    @Override public boolean deleteSurroundingText(int before, int after) {
                        if (!composing.isEmpty()) {
                            composing = composing.substring(0, Math.max(0, composing.length() - before));
                            return true;
                        }
                        for (int i = 0; i < before; i++) sendText("", true);
                        return true;
                    }
                    @Override public boolean sendKeyEvent(KeyEvent event) {
                        if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
                        if (event.getKeyCode() == KeyEvent.KEYCODE_DEL) sendText("", true);
                        else if (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) sendText("\n", false);
                        else if (event.getUnicodeChar() != 0) sendText(new String(Character.toChars(event.getUnicodeChar())), false);
                        return true;
                    }
                };
            }
        };
        inputView.setFocusableInTouchMode(true);
        addContentView(inputView, new FrameLayout.LayoutParams(1, 1));
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, this::onBackPressed);
        }
        getWindow().getDecorView().setOnApplyWindowInsetsListener((view, insets) -> {
            complete(-4, windowInsets(insets));
            return view.onApplyWindowInsets(insets);
        });
        if (android.os.Build.VERSION.SDK_INT < 30) {
            inputView.getViewTreeObserver().addOnGlobalLayoutListener(() -> {
                android.graphics.Rect visible = new android.graphics.Rect();
                getWindow().getDecorView().getWindowVisibleDisplayFrame(visible);
                int height = Math.max(0, getWindow().getDecorView().getHeight() - visible.bottom);
                if (height < 100 * getResources().getDisplayMetrics().density) height = 0;
                complete(-2, object("text", Integer.toString(height)));
            });
        }
    }

    @Override public void onResume() { super.onResume(); foreground = true; }
    @Override public void onPause() { foreground = false; stopSpeaking(); super.onPause(); }
    @Override public void onBackPressed() {
        if (bridgeReady) complete(-3, new JSONObject());
        else super.onBackPressed();
    }
    @Override public void onDestroy() {
        stopSpeaking();
        if (speaker != null) speaker.shutdown();
        if (promptRequest != 0) complete(promptRequest, object("cancelled", true));
        if (authRequest != 0) complete(authRequest, object("cancelled", true));
        if (prompt != null) prompt.dismiss();
        for (long request : new ArrayList<>(pending.values())) complete(request, object("cancelled", true));
        pending.clear();
        files.shutdownNow();
        super.onDestroy();
    }

    // Called synchronously by Swift on the main looper. Binary JSON uses base64 to
    // avoid JNI modified UTF-8 corrupting emoji and non-BMP characters.
    public String call(String action, String payload, long request) {
        bridgeReady = true;
        try {
            JSONObject args = new JSONObject(new String(Base64.decode(payload, Base64.DEFAULT), StandardCharsets.UTF_8));
            String text = args.optString("text"), key = args.optString("key");
            switch (action) {
                case "foreground": return encode(object("flag", foreground));
                case "insets": return encode(windowInsets(inputView.getRootWindowInsets()));
                case "copy":
                    ((ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("Ada Studio", text));
                    break;
                case "authenticate":
                    if (authRequest != 0) throw new Exception("Sign-in is already in progress.");
                    authRequest = request;
                    try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(text))); }
                    catch (Exception error) { authRequest = 0; throw error; }
                    break;
                case "auth.cancel":
                    long cancelled = authRequest; authRequest = 0;
                    if (cancelled != 0) complete(cancelled, object("cancelled", true));
                    break;
                case "credential.read": return encode(object("text", readCredential(key)));
                case "credential.write": writeCredential(key, text); break;
                case "credential.delete":
                    if (!getSharedPreferences("credentials", MODE_PRIVATE).edit().remove(key).commit()) throw new Exception("Could not remove credentials.");
                    break;
                case "keyboard.show":
                    inputView.requestFocus();
                    ((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).restartInput(inputView);
                    ((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showSoftInput(inputView, InputMethodManager.SHOW_IMPLICIT);
                    break;
                case "keyboard.hide":
                    ((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).hideSoftInputFromWindow(inputView.getWindowToken(), 0);
                    inputView.clearFocus();
                    break;
                case "prompt":
                    if (prompt != null) throw new Exception("Close the current dialog first.");
                    EditText field = new EditText(this);
                    field.setText(text);
                    field.setInputType(InputType.TYPE_CLASS_TEXT | (args.optBoolean("secret") ? InputType.TYPE_TEXT_VARIATION_PASSWORD : InputType.TYPE_TEXT_FLAG_MULTI_LINE));
                    promptRequest = request;
                    prompt = new AlertDialog.Builder(this).setTitle(key).setView(field)
                        .setPositiveButton("Save", (dialog, which) -> complete(request, object("text", field.getText().toString())))
                        .setNegativeButton("Cancel", (dialog, which) -> complete(request, object("cancelled", true)))
                        .setOnCancelListener(dialog -> complete(request, object("cancelled", true))).create();
                    prompt.setOnDismissListener(dialog -> { prompt = null; promptRequest = 0; });
                    prompt.show();
                    break;
                case "pick.files": case "pick.images":
                    if (pending.containsKey(DOCUMENTS)) throw new Exception("A file picker is already open.");
                    Intent picker = new Intent(Intent.ACTION_OPEN_DOCUMENT).setType(action.equals("pick.images") ? "image/*" : "*/*")
                        .addCategory(Intent.CATEGORY_OPENABLE).putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
                    pending.put(DOCUMENTS, request);
                    try { startActivityForResult(picker, DOCUMENTS); }
                    catch (Exception error) { pending.remove(DOCUMENTS); throw error; }
                    break;
                case "dictate":
                    if (pending.containsKey(SPEECH)) throw new Exception("Dictation is already open.");
                    Intent speech = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag());
                    pending.put(SPEECH, request);
                    try { startActivityForResult(speech, SPEECH); }
                    catch (Exception error) { pending.remove(SPEECH); throw new Exception("Speech recognition is unavailable. Use the keyboard."); }
                    break;
                case "speak":
                    stopSpeaking();
                    speechRequest = request;
                    speechText = text;
                    if (speaker == null) {
                        speaker = new TextToSpeech(this, status -> {
                            speakerReady = status == TextToSpeech.SUCCESS;
                            if (!speakerReady) finishSpeaking(object("error", "Speech output is unavailable."));
                            else beginSpeaking();
                        });
                        speaker.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                            public void onStart(String id) { }
                            public void onDone(String id) { runOnUiThread(() -> { if (id.equals(Long.toString(speechRequest))) finishSpeaking(new JSONObject()); }); }
                            public void onError(String id) { runOnUiThread(() -> { if (id.equals(Long.toString(speechRequest))) finishSpeaking(object("error", "Could not speak the reply.")); }); }
                        });
                    } else if (speakerReady) beginSpeaking();
                    else throw new Exception("Speech output is unavailable.");
                    break;
                case "speech.stop": stopSpeaking(); break;
                default: throw new Exception("Unknown Android service: " + action);
            }
            return encode(new JSONObject());
        } catch (Exception error) { return encode(object("error", error.getMessage())); }
    }

    @Override protected void onActivityResult(int code, int result, Intent data) {
        super.onActivityResult(code, result, data);
        Long request = pending.get(code);
        if (request == null) return;
        if (result != RESULT_OK || data == null) { pending.remove(code); complete(request, object("cancelled", true)); return; }
        if (code == SPEECH) {
            pending.remove(code);
            ArrayList<String> values = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            complete(request, object("text", values == null || values.isEmpty() ? "" : values.get(0)));
        } else if (code == DOCUMENTS) {
            ArrayList<Uri> urls = new ArrayList<>();
            ClipData clips = data.getClipData();
            if (clips != null) { for (int i = 0; i < Math.min(8, clips.getItemCount()); i++) urls.add(clips.getItemAt(i).getUri()); }
            else if (data.getData() != null) urls.add(data.getData());
            files.execute(() -> {
                ArrayList<File> copied = new ArrayList<>();
                JSONObject reply;
                try {
                    JSONArray paths = new JSONArray();
                    for (Uri uri : urls) {
                        String name = "attachment";
                        try (Cursor cursor = getContentResolver().query(uri, new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                            if (cursor != null && cursor.moveToFirst()) name = cursor.getString(0);
                        }
                        File target = new File(getCacheDir(), UUID.randomUUID() + "-" + new File(name).getName());
                        copied.add(target);
                        try (InputStream input = getContentResolver().openInputStream(uri); OutputStream output = Files.newOutputStream(target.toPath())) {
                            if (input == null) throw new Exception("The selected document is unavailable.");
                            byte[] buffer = new byte[16384]; int count, size = 0;
                            while ((count = input.read(buffer)) != -1) {
                                size += count;
                                if (size > MAX_FILE_BYTES) throw new Exception("Choose files up to 8 MB each.");
                                output.write(buffer, 0, count);
                            }
                        }
                        paths.put(target.getAbsolutePath());
                    }
                    reply = object("paths", paths);
                } catch (Exception error) {
                    for (File file : copied) file.delete();
                    reply = object("error", error.getMessage());
                }
                JSONObject value = reply;
                runOnUiThread(() -> {
                    if (pending.remove(DOCUMENTS) != null) complete(request, value);
                });
            });
        }
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        Uri url = intent.getData();
        if (authRequest != 0 && url != null && "adaeditor".equals(url.getScheme())
                && "cloud".equals(url.getHost()) && "/callback".equals(url.getPath())) {
            long request = authRequest; authRequest = 0;
            // Swift validates the PKCE state and code before exchanging credentials.
            complete(request, object("text", url.toString()));
        }
    }

    private SecretKey credentialKey() throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore"); store.load(null);
        String alias = "AdaStudioCredentials";
        if (!store.containsAlias(alias)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey)store.getKey(alias, null);
    }

    private JSONObject windowInsets(WindowInsets insets) {
        if (insets == null) return new JSONObject();
        int top, left, bottom, right, keyboard = 0;
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            android.graphics.Insets safe = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout());
            top = safe.top; left = safe.left; bottom = safe.bottom; right = safe.right;
            keyboard = insets.getInsets(WindowInsets.Type.ime()).bottom;
        } else {
            top = insets.getSystemWindowInsetTop(); left = insets.getSystemWindowInsetLeft();
            bottom = insets.getStableInsetBottom(); right = insets.getSystemWindowInsetRight();
        }
        JSONArray safe = new JSONArray(); safe.put(top); safe.put(left); safe.put(bottom); safe.put(right);
        JSONObject value = object("insets", safe);
        try { value.put("text", Integer.toString(keyboard)); } catch (Exception ignored) { }
        return value;
    }

    private void beginSpeaking() {
        if (speechRequest == 0) return;
        speaker.setLanguage(Locale.getDefault());
        if (speaker.speak(speechText, TextToSpeech.QUEUE_FLUSH, null, Long.toString(speechRequest)) == TextToSpeech.ERROR)
            finishSpeaking(object("error", "Could not speak the reply."));
    }
    private void finishSpeaking(JSONObject reply) {
        long request = speechRequest;
        speechRequest = 0; speechText = null;
        if (request != 0) complete(request, reply);
    }
    private void stopSpeaking() {
        if (speaker != null) speaker.stop();
        finishSpeaking(object("cancelled", true));
    }

    private void writeCredential(String key, String text) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, credentialKey());
        JSONObject record = object("iv", Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP));
        record.put("data", Base64.encodeToString(cipher.doFinal(text.getBytes(StandardCharsets.UTF_8)), Base64.NO_WRAP));
        if (!getSharedPreferences("credentials", MODE_PRIVATE).edit().putString(key, record.toString()).commit()) throw new Exception("Could not save credentials.");
    }

    private String readCredential(String key) throws Exception {
        String stored = getSharedPreferences("credentials", MODE_PRIVATE).getString(key, null);
        if (stored == null) return "";
        JSONObject record = new JSONObject(stored);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, credentialKey(), new GCMParameterSpec(128, Base64.decode(record.getString("iv"), Base64.DEFAULT)));
        return new String(cipher.doFinal(Base64.decode(record.getString("data"), Base64.DEFAULT)), StandardCharsets.UTF_8);
    }

    private void sendText(String text, boolean delete) {
        JSONObject value = object("text", text);
        try { value.put("flag", delete); } catch (Exception ignored) { }
        complete(-1, value);
    }
    private static JSONObject object(String key, Object value) {
        JSONObject object = new JSONObject();
        try { object.put(key, value); } catch (Exception ignored) { }
        return object;
    }
    private static String encode(JSONObject value) {
        return Base64.encodeToString(value.toString().getBytes(StandardCharsets.UTF_8), Base64.NO_WRAP);
    }
    private void complete(long request, JSONObject value) { if (bridgeReady) deliver(request, encode(value)); }
}
