package de.jpaw.bonaparte.dsl.generator.ts;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.resource.Resource;

import de.jpaw.bonaparte.dsl.BonScriptPreferences;

public final class TsModuleResolver {
    private static final String POM_PROPERTIES = "META-INF/maven/";
    private static final String MODULES_PROPERTY_SEPARATOR = ",";

    private TsModuleResolver() {
    }

    public static boolean isCurrentModule(Resource resource) {
        String currentModule = BonScriptPreferences.getTsModule();
        String resourceModule = moduleId(resource.getURI());
        if (resourceModule == null)
            return true;
        return currentModule != null && currentModule.equals(resourceModule);
    }

    public static boolean isSameModule(EObject left, EObject right) {
        if (left.eResource() == null || right.eResource() == null)
            return true;
        String leftModule = moduleId(left.eResource().getURI());
        String rightModule = moduleId(right.eResource().getURI());
        return leftModule == null || rightModule == null || leftModule.equals(rightModule);
    }

    public static String typeGuard(String typeName, String pqon) {
        return "export function is" + typeName + "(value: unknown): value is " + typeName + " {\n"
                + "    return typeof value === \"object\" && value !== null && (value as Record<string, unknown>)[\"@PQON\"] === \""
                + pqon + "\";\n"
                + "}\n";
    }

    public static String crossModuleImport(EObject from, EObject target) {
        if (from.eResource() == null || target.eResource() == null)
            return null;
        String currentModule = moduleId(from.eResource().getURI());
        String targetModule = moduleId(target.eResource().getURI());
        if (currentModule == null || targetModule == null || currentModule.equals(targetModule))
            return null;

        String modulesFile = BonScriptPreferences.getTsModulesFile();
        if (modulesFile == null || modulesFile.isBlank())
            throw new IllegalStateException("Cross-module TypeScript import from " + currentModule + " to "
                    + targetModule + " requires bonaparte.TypeScript.modulesFile");

        Properties modules = loadModules(modulesFile);
        if (!modules.containsKey(targetModule))
            throw new IllegalStateException("TypeScript dependency closure for " + currentModule
                    + " does not contain module " + targetModule);
        return importSpecifier(targetModule, modules);
    }

    public static String importSpecifier(String artifactId, Properties modules) {
        String[] mapping = moduleMapping(artifactId, modules);
        return mapping[0] + "/" + mapping[1];
    }

    public static String currentEntryPoint() {
        String currentModule = BonScriptPreferences.getTsModule();
        String modulesFile = BonScriptPreferences.getTsModulesFile();
        if (currentModule == null || currentModule.isBlank() || modulesFile == null || modulesFile.isBlank())
            return null;
        return entryPoint(currentModule, loadModules(modulesFile));
    }

    public static String outputFolder() {
        String entryPoint = currentEntryPoint();
        return entryPoint == null ? "resources/ts/" : "resources/ts/" + entryPoint + "/";
    }

    public static String entryPoint(String artifactId, Properties modules) {
        return moduleMapping(artifactId, modules)[1];
    }

    private static String[] moduleMapping(String artifactId, Properties modules) {
        String[] mapping = modules.getProperty(artifactId, "").split(MODULES_PROPERTY_SEPARATOR, 2);
        if (mapping.length != 2 || mapping[0].isBlank() || mapping[1].isBlank())
            throw new IllegalStateException("Invalid or missing TypeScript module mapping for " + artifactId
                    + ": expected <npm-package>,<entry-point>");
        return new String[] { mapping[0].trim(), mapping[1].trim() };
    }

    private static Properties loadModules(String path) {
        Properties modules = new Properties();
        try (InputStream input = new FileInputStream(path)) {
            modules.load(input);
        } catch (IOException e) {
            throw new IllegalStateException("Cannot read TypeScript module map " + path, e);
        }
        return modules;
    }

    private static String moduleId(URI uri) {
        String value = uri.toString();
        if (value.startsWith("jar:") || value.startsWith("archive:"))
            return moduleIdFromJar(value);
        if (value.startsWith("file:"))
            return BonScriptPreferences.getTsModule();
        return null;
    }

    private static String moduleIdFromJar(String resourceUri) {
        int bang = resourceUri.indexOf('!');
        if (bang < 0)
            return null;
        String jarUri = resourceUri.substring(resourceUri.indexOf(':') + 1, bang);
        File jarFile = new File(URI.createURI(jarUri).toFileString());
        try (JarFile jar = new JarFile(jarFile)) {
            var entries = jar.entries();
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.startsWith(POM_PROPERTIES) && name.endsWith("/pom.properties")) {
                    try (InputStream input = jar.getInputStream(entry)) {
                        Properties properties = new Properties();
                        properties.load(input);
                        String artifactId = properties.getProperty("artifactId");
                        if (artifactId != null)
                            return artifactId;
                    }
                }
            }
        } catch (IOException e) {
            throw new IllegalStateException("Cannot resolve BonScript module from " + jarFile, e);
        }
        return null;
    }
}