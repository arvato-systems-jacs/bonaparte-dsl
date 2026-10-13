package de.jpaw.bonaparte.dsl.generator;

import org.apache.log4j.Logger;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.resource.DerivedStateAwareResource;
import org.eclipse.xtext.resource.IDerivedStateComputer;

import de.jpaw.bonaparte.dsl.bonScript.PackageDefinition;

public class PackageEnricher implements IDerivedStateComputer {
    static final Logger LOGGER = Logger.getLogger(PackageEnricher.class);

    private String getMavenModuleName(Resource resource) {
        final String uri = resource.getURI().toString();

        // determine desired components out of URI (which could be like file:/Users/bisc02/src/jacs/t9t/t9t-base-api/src/main/bon/base/ui.bon)
        // we parse the URI under the assumption that maven folder syntax is used
        final int lastSlash = uri.lastIndexOf('/');
        final String filename = lastSlash >= 0 ? uri.substring(lastSlash + 1) : null;
        final int startOfPath = uri.indexOf("/src/main/");
        String mavenModule = null;
        if (startOfPath > 0) {
            final String modulePath = uri.substring(0, startOfPath);
            final int endOfProjectPath = modulePath.lastIndexOf('/');
            if (endOfProjectPath >= 0) {
                mavenModule = modulePath.substring(endOfProjectPath + 1);
            }
        }
        if (filename == null || mavenModule == null) {
            LOGGER.error("Could not determine project and file name from URI " + uri);
            return null;  // no EObject enrichment will be done
        }
        return mavenModule;
    }

    @Override
    public void installDerivedState(DerivedStateAwareResource resource, boolean preLinkingPhase) {

        final String mavenModule = getMavenModuleName(resource);
        if (mavenModule == null) {
            // check if there is existing info
            resource.getAllContents().forEachRemaining(object -> {
                if (object instanceof PackageDefinition pd) {
                    for (var a : object.eAdapters()) {
                        if (a instanceof ModuleInfo mi) {
                            LOGGER.info("Existing maven module " + mi.getMavenModule() + " found for package " + pd.getName() + " in file " + resource.getURI().lastSegment());
                        }
                    }
                }
            });
        } else {
            // assign info
            resource.getAllContents().forEachRemaining(object -> {
                if (object instanceof PackageDefinition pd) {
                    object.eAdapters().removeIf(a -> a instanceof ModuleInfo);
                    object.eAdapters().add(new ModuleInfo(mavenModule));
                    LOGGER.info("Assigning maven module " + mavenModule + " to package " + pd.getName() + " in file " + resource.getURI().lastSegment());
                }
            });
        }
    }

    @Override
    public void discardDerivedState(DerivedStateAwareResource resource) {
        resource.getAllContents().forEachRemaining(object ->
            object.eAdapters().removeIf(a -> a instanceof ModuleInfo));
    }
}