import mongoose from 'mongoose';

let cachedConnection = null;

/**
 * Replaces the database name in a MongoDB connection string
 * @param {string} uri - The MongoDB connection string
 * @param {string} dbName - The database name to use
 * @returns {string} - The connection string with the database name replaced
 */
const replaceDatabaseName = (uri, dbName) => {
  if (!uri || !dbName) {
    return uri;
  }

  try {
    // Parse the MongoDB URI
    const url = new URL(uri);
    
    // Replace the database name (pathname without leading slash)
    url.pathname = `/${dbName}`;
    
    return url.toString();
  } catch (error) {
    // If URL parsing fails, try regex replacement as fallback
    // This handles cases where the URI might not be a standard URL format
    const dbNamePattern = /(mongodb\+?srv?:\/\/[^\/]+)\/[^?]*(\?.*)?$/;
    if (dbNamePattern.test(uri)) {
      return uri.replace(dbNamePattern, `$1/${dbName}$2`);
    }
    // If we can't parse it, return original URI
    console.warn('Could not parse MongoDB URI for database name replacement:', error.message);
    return uri;
  }
};

/**
 * Gets the MongoDB connection URI, with database name override if MONGODB_DB_NAME is set
 * @returns {string} - The MongoDB connection string with database name replaced if needed
 */
const getMongoUri = () => {
  let uri = process.env.MONGODB_URI;
  
  if (!uri) {
    throw new Error('MONGODB_URI environment variable is not set');
  }

  // If MONGODB_DB_NAME is set, replace the database name in the URI
  if (process.env.MONGODB_DB_NAME) {
    uri = replaceDatabaseName(uri, process.env.MONGODB_DB_NAME);
    console.log(`Using database: ${process.env.MONGODB_DB_NAME}`);
  } else {
    // Extract database name from URI for logging
    try {
      const url = new URL(uri);
      const dbName = url.pathname.replace(/^\//, '') || 'default';
      console.log(`Using database from URI: ${dbName}`);
    } catch (error) {
      console.log('Using database from MONGODB_URI (could not parse for logging)');
    }
  }

  return uri;
};

const connectDB = async () => {
  if (cachedConnection) {
    return cachedConnection;
  }

  try {
    const uri = getMongoUri();
    const connection = await mongoose.connect(uri);

    cachedConnection = connection;
    console.log('MongoDB connected successfully');
    return connection;
  } catch (error) {
    console.error('MongoDB connection error:', error);
    throw error;
  }
};

export default connectDB;

