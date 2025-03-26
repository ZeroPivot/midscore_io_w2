<?php
// Define the website base directory as a constant
define('BASE_DIR', '/home/dh_6b77xu/hudlink.us');

// Check if the request method is POST and the content type is multipart/form-data
if ($_SERVER['REQUEST_METHOD'] != 'POST' || strpos($_SERVER['CONTENT_TYPE'], 'multipart/form-data') === false) {
    echo "Invalid request method or content type";
    exit();
}

// Get the absolute file location string from the POST variable 'path'
$path = $_POST['path'];
// Get the password from the POST variable 'password'
$password = $_POST['password'];
// Get the file data from the POST variable 'file'
$file = $_FILES['file'];

// Validate the input parameters
if (!$path || !$password || !$file) {
    echo "Invalid input parameters";
    exit();
}

// Check if the password matches the expected value
if ($password != '859CDFE#F4E100') {
    echo "Invalid password";
    exit();
}

// Remove any trailing slashes from the path
$path = rtrim($path, '/');
// Get the directory name and the file name from the path
$dir = dirname($path);

// Get the file name from the POST variable 'file'
$name = $_FILES['file']['name'];

// Prepend the website base directory to the path
$full_path = BASE_DIR . $path;

// Create the directory recursively if it does not exist
if (!is_dir($full_path)) {
    mkdir($full_path, 0777, true);
}

// Check if the directory is writable
if (!is_writable($full_path)) {
    // Try to change the directory permissions to make it writable
    if (!chmod($full_path, 0777)) {
        echo "Directory is not writable and could not be fixed";
        exit();
    }
}

// Move the uploaded file to the destination directory with the given file name
if (move_uploaded_file($file['tmp_name'], $full_path . '/' . $name)) {
    echo "File uploaded successfully to $path ($name)";
} else {
    echo "File upload failed";
}
?>
