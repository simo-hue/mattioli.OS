import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const DIST_DIR = join(__dirname, '..', 'dist');
const INDEX_HTML = join(DIST_DIR, 'index.html');

// Define all public routes that need static HTML files
const PUBLIC_ROUTES = [
    'features',
    'faq',
    'tech',
    'philosophy',
    'get-started',
    'creator'
];

function generateStaticRoutes() {
    console.log('🚀 Starting static routes generation...\n');

    // Check if dist/index.html exists
    if (!existsSync(INDEX_HTML)) {
        console.error('❌ Error: dist/index.html not found. Make sure to run "vite build" first.');
        process.exit(1);
    }

    // Read the index.html content
    const indexContent = readFileSync(INDEX_HTML, 'utf-8');

    let successCount = 0;
    let errorCount = 0;

    // Generate static HTML for each route
    PUBLIC_ROUTES.forEach(route => {
        try {
            const routeDir = join(DIST_DIR, route);
            const routeIndexPath = join(routeDir, 'index.html');

            // Create directory if it doesn't exist
            if (!existsSync(routeDir)) {
                mkdirSync(routeDir, { recursive: true });
            }

            // Copy index.html to route directory
            writeFileSync(routeIndexPath, indexContent);

            console.log(`✅ Created: ${route}/index.html`);
            successCount++;
        } catch (error) {
            console.error(`❌ Failed to create ${route}/index.html:`, error.message);
            errorCount++;
        }
    });

    // Summary
    console.log(`\n📊 Summary:`);
    console.log(`   ✅ Successfully created: ${successCount} route(s)`);
    if (errorCount > 0) {
        console.log(`   ❌ Failed: ${errorCount} route(s)`);
        process.exit(1);
    }

    console.log('\n🎉 Static routes generation completed successfully!');
}

// Run the script
generateStaticRoutes();
