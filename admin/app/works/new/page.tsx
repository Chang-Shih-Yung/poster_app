import PageShell from "@/components/PageShell";
import WorkForm from "./WorkForm";

export default function NewWorkPage() {
  return (
    <PageShell title="新增作品" back>
      <div className="px-4 py-4 md:px-0 md:py-0">
        <h1 className="hidden md:block text-2xl font-semibold tracking-tight mb-6">
          新增作品
        </h1>
        <WorkForm mode="create" />
      </div>
    </PageShell>
  );
}
