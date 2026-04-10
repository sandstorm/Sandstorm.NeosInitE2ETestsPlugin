<?php
declare(strict_types=1);

namespace Sandstorm\NeosInitE2ETestsPlugin;

use Composer\Command\BaseCommand;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;

class InitCommand extends BaseCommand
{
    protected function configure(): void
    {
        $this->setName('e2e:init')
            ->setDescription('Scaffold E2E test infrastructure into the current project.');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $composer = $this->requireComposer();
        $rootPackage = $composer->getPackage();
        $composerName = $rootPackage->getPrettyName();

        $packageName = $composerName;
        $extra = $rootPackage->getExtra();
        $packageKey = $extra['neos']['package-key'] ?? $this->derivePackageKey($composerName);

        $templateDir = dirname(__DIR__) . '/template';
        $projectRoot = dirname($composer->getConfig()->getConfigSource()->getName());

        $output->writeln('<info>sandstorm/neos-init-e2e-tests-plugin:</info> Scaffolding E2E test infrastructure...');
        $output->writeln("  PackageName: <comment>$packageName</comment>");
        $output->writeln("  PackageKey:  <comment>$packageKey</comment>");

        $this->writeTemplate($templateDir, $projectRoot, $packageName, $packageKey, $output);

        $output->writeln('<info>Done.</info>');
        return 0;
    }

    private function derivePackageKey(string $composerName): string
    {
        $parts = explode('/', $composerName, 2);
        return implode('.', array_map([$this, 'toStudlyCaps'], $parts));
    }

    private function toStudlyCaps(string $segment): string
    {
        return implode('', array_map('ucfirst', preg_split('/[-_]+/', $segment)));
    }

    private function writeTemplate(
        string          $sourceDir,
        string          $targetDir,
        string          $packageName,
        string          $packageKey,
        OutputInterface $output
    ): void
    {
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($sourceDir),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($iterator as $item) {
            $relativePath = substr($item->getPathname(), strlen($sourceDir) + 1);
            $destination = $targetDir . DIRECTORY_SEPARATOR . $relativePath;

            if ($item->isDir()) {
                if (!is_dir($destination)) {
                    mkdir($destination, 0755, true);
                }
                continue;
            }

            if (file_exists($destination)) {
                $output->writeln(
                    "  - <comment>Skipping existing:</comment> $relativePath",
                    OutputInterface::VERBOSITY_VERBOSE
                );
                continue;
            }

            $content = file_get_contents($item->getPathname());
            if ($content === false) {
                $output->writeln("  - <error>Failed to read:</error> $relativePath");
                continue;
            }

            $content = str_replace(
                ['{{PackageName}}', '{{PackageKey}}'],
                [$packageName, $packageKey],
                $content
            );

            $parentDir = dirname($destination);
            if (!is_dir($parentDir)) {
                mkdir($parentDir, 0755, true);
            }

            if (file_put_contents($destination, $content) === false) {
                $output->writeln("  - <error>Failed to write:</error> $relativePath");
                continue;
            }

            $output->writeln("  - Created: $relativePath");
        }
    }
}
