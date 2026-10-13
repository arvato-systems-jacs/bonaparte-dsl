package de.jpaw.bonaparte.dsl.generator;

import org.eclipse.emf.common.notify.impl.AdapterImpl;

// Transient metadata attached to an EObject; it is not part of the DSL syntax.
public final class ModuleInfo extends AdapterImpl {
    private final String mavenModule;   // the name of the maven module ("project"), used for typescript package
    private final String fileName;      // name of the bon file defining the object
    private final String packageName;   // the PQON of the java package, used for the typescript module

    public ModuleInfo(String mavenModule, String fileName, String packageName) {
        this.mavenModule = mavenModule;
        this.fileName = fileName;
        this.packageName = packageName;
    }

    public String getMavenModule() {
        return mavenModule;
    }

    public String getFileName() {
        return fileName;
    }

    public String getPackageName() {
        return packageName;
    }

    @Override
    public boolean isAdapterForType(Object type) {
        return type == ModuleInfo.class;
    }
}
