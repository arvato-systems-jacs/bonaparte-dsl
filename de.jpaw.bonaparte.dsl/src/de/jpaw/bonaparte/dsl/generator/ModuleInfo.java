package de.jpaw.bonaparte.dsl.generator;

import org.eclipse.emf.common.notify.impl.AdapterImpl;

// Transient metadata attached to an EObject; it is not part of the DSL syntax.
public final class ModuleInfo extends AdapterImpl {
    private final String mavenModule;   // the name of the maven module ("project"), used for typescript package

    public ModuleInfo(String mavenModule) {
        this.mavenModule = mavenModule;
    }

    public String getMavenModule() {
        return mavenModule;
    }

    @Override
    public boolean isAdapterForType(Object type) {
        return type == ModuleInfo.class;
    }
}
