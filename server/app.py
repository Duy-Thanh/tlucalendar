import os
import uuid
import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configure upload folder
UPLOAD_FOLDER = 'uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

@app.route('/submit', methods=['POST'])
def upload_minidump():
    if 'upload_file_minidump' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    
    file = request.files['upload_file_minidump']
    
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
    
    if file:
        # Generate a unique filename using timestamp and UUID
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_id = str(uuid.uuid4())[:8]
        
        # Preserve original extension (e.g., .txt for Dart logs, .dmp for Native)
        _, ext = os.path.splitext(file.filename)
        if not ext:
            ext = ".dmp"
            
        filename = f"crash_{timestamp}_{unique_id}{ext}"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        
        file.save(filepath)
        
        # Save additional metadata if present (Crashpad sends key-value pairs)
        meta_filepath = filepath + ".meta"
        with open(meta_filepath, "w") as f:
            for key, value in request.form.items():
                f.write(f"{key}={value}\n")
        
        return jsonify({'message': 'File uploaded successfully', 'id': filename}), 200

    return jsonify({'error': 'Upload failed'}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'ok'}), 200

if __name__ == '__main__':
    # Run on all interfaces
    app.run(host='0.0.0.0', port=5100)
