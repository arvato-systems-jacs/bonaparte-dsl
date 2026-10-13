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
        String mavenModule = null;

        // first, distinguish between URIs inside a jar and outside a jar. Inside a JAR starts with archive:, and the subsequent parts need to be parsed differently.
        if (uri.startsWith("archive:")) {
            // inside a jar, a possible URI is of the form archive:file:/Users/bisc02/.m2/repository/de/jpaw/bonaparte-api/7.3.2/bonaparte-api-7.3.2.jar!/api.bon
            // we strip off anything after the last !, and then use the part after the previous slash
            final int lastExclamation = uri.lastIndexOf('!');
            if (lastExclamation > 0) {
                final int lastSlash = uri.lastIndexOf('/', lastExclamation);
                final String jarName = uri.substring(lastSlash + 1, lastExclamation);
                // use the start of jarName, until you encounter the first dash, which is followed by a digit
                mavenModule = jarName.replaceFirst("-(?=\\d)[\\s\\S]*", "");
            }
        } else {
            // determine desired components out of URI (which could be like file:/Users/bisc02/src/jacs/t9t/t9t-base-api/src/main/bon/base/ui.bon)
            // we parse the URI under the assumption that maven folder syntax is used
            final int startOfPath = uri.indexOf("/src/main/");
            if (startOfPath > 0) {
                final String modulePath = uri.substring(0, startOfPath);
                final int endOfProjectPath = modulePath.lastIndexOf('/');
                if (endOfProjectPath >= 0) {
                    mavenModule = modulePath.substring(endOfProjectPath + 1);
                }
            }
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